import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';

import 'starter_module_registration.dart';

/// Starts and observes only the modules explicitly selected by an application.
final class GenRevibesStarterKit implements StarterModule {
  /// Creates a provider-agnostic starter-kit coordinator.
  ///
  /// [moduleTimeout] bounds how long a single module may spend in
  /// `initialize()`. Vendor SDKs bridge callbacks to futures, and a callback
  /// that never fires would otherwise suspend startup permanently with no
  /// error, no log and an empty Dart stack. A module that overruns its budget
  /// is recorded as a timeout failure and the remaining modules still start,
  /// which is the whole point of a health model: a broken capability degrades,
  /// it does not take the application down with it.
  GenRevibesStarterKit({
    required Iterable<StarterModuleRegistration> modules,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
    Duration moduleTimeout = const Duration(seconds: 10),
  })  : _registrations = List<StarterModuleRegistration>.unmodifiable(modules),
        _clock = clock,
        _logger = logger,
        _moduleTimeout = moduleTimeout,
        _health = ModuleHealth(
          moduleId: 'starter_kit',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final List<StarterModuleRegistration> _registrations;
  final KitClock _clock;
  final KitLogger _logger;
  final Duration _moduleTimeout;
  final Map<String, StarterModule> _modules = <String, StarterModule>{};
  final Map<String, StreamSubscription<ModuleHealth>> _subscriptions =
      <String, StreamSubscription<ModuleHealth>>{};
  final Map<String, KitError> _initializationErrors = <String, KitError>{};
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  late ModuleHealth _health;
  Future<KitResult<void>>? _initialization;
  KitResult<void>? _lastInitializationResult;
  bool _initializationInProgress = false;
  Future<void>? _deferredStartup;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => 'starter_kit';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  /// Instantiated enabled modules, keyed by stable module ID.
  Map<String, StarterModule> get modules =>
      Map<String, StarterModule>.unmodifiable(_modules);

  /// Completes when every deferred module has finished starting.
  ///
  /// Startup does not wait for these, but a caller that actually depends on one
  /// must. An ad request, for example, may not be made before consent has been
  /// gathered, so the ad path awaits this rather than the application doing so.
  ///
  /// Completes normally whatever the outcome; a deferred failure is reported on
  /// that module's health, not here. Returns immediately when there are no
  /// deferred modules or initialization has not run.
  Future<void> get deferredStartupComplete =>
      _deferredStartup ?? Future<void>.value();

  /// Returns an initialized module without introducing a service locator.
  T? module<T extends StarterModule>(String moduleId) {
    final value = _modules[moduleId];
    return value is T ? value : null;
  }

  @override
  Future<KitResult<void>> initialize() {
    if (_disposed) {
      return Future<KitResult<void>>.value(_notReady());
    }
    if (_initialized) {
      return Future<KitResult<void>>.value(
        _lastInitializationResult ?? const KitSuccess<void>(null),
      );
    }
    final active = _initialization;
    if (active != null) return active;
    final started = _initializeOnce();
    _initialization = started;
    return started.whenComplete(() => _initialization = null);
  }

  Future<KitResult<void>> _initializeOnce() async {
    final validation = _validateRegistrations();
    if (validation != null) {
      _initialized = true;
      _lastInitializationResult = KitFailure<void>(validation);
      _setHealth(ModuleState.failed, error: validation);
      return _lastInitializationResult!;
    }

    _initializationInProgress = true;
    _setHealth(ModuleState.initializing);
    KitError? firstRequiredError;
    for (final registration in _registrations
        .where((item) => item.enabled && !item.isDeferred)) {
      StarterModule module;
      try {
        module = registration.create!();
      } on Object catch (error, stackTrace) {
        final mapped = KitError(
          code: KitErrorCode.unknown,
          message: 'Module factory ${registration.moduleId} failed: $error',
          cause: error,
          stackTrace: stackTrace,
        );
        _recordInitializationError(registration, mapped);
        firstRequiredError ??= registration.isRequired ? mapped : null;
        continue;
      }

      // An adapter names itself under the capability it implements:
      // `ads.admob` for the `ads` registration, `notifications.push.onesignal`
      // for `notifications.push`. Registering an adapter directly under its
      // capability is the ordinary composition, so a namespaced child is
      // accepted; only an unrelated module is a configuration error.
      final moduleId = module.moduleId;
      final registeredId = registration.moduleId;
      if (moduleId != registeredId && !moduleId.startsWith('$registeredId.')) {
        final mapped = KitError(
          code: KitErrorCode.invalidConfiguration,
          message: 'Registration $registeredId created unrelated module '
              '$moduleId.',
        );
        _recordInitializationError(registration, mapped);
        firstRequiredError ??= registration.isRequired ? mapped : null;
        await module.dispose();
        continue;
      }

      _modules[registration.moduleId] = module;
      _subscriptions[registration.moduleId] = module.healthChanges.listen(
        (health) => _onModuleHealthChanged(registration.moduleId, health),
      );
      KitResult<void> result;
      _logger.log(
        KitLogLevel.debug,
        'Starter-kit module initialization started.',
        moduleId: registration.moduleId,
      );
      try {
        result = await module.initialize().timeout(
              _moduleTimeout,
              // The underlying work is not cancellable, so it may still settle
              // later and update this module's health. What matters here is
              // that startup is released.
              onTimeout: () => KitFailure<void>(
                KitError(
                  code: KitErrorCode.timeout,
                  message: 'Module ${registration.moduleId} did not finish '
                      'initializing within '
                      '${_moduleTimeout.inMilliseconds}ms.',
                  metadata: <String, Object?>{
                    'moduleId': registration.moduleId,
                    'timeoutMs': _moduleTimeout.inMilliseconds,
                  },
                ),
              ),
            );
      } on Object catch (error, stackTrace) {
        result = KitFailure<void>(
          KitError(
            code: KitErrorCode.unknown,
            message: 'Module ${registration.moduleId} threw during startup: '
                '$error',
            cause: error,
            stackTrace: stackTrace,
          ),
        );
      }
      result.fold(
        onSuccess: (_) => _logger.log(
          KitLogLevel.info,
          'Starter-kit module ready.',
          moduleId: registration.moduleId,
        ),
        onFailure: (error) {
          _recordInitializationError(registration, error);
          firstRequiredError ??= registration.isRequired ? error : null;
        },
      );
    }

    _initializationInProgress = false;
    _initialized = true;
    // Not awaited: that is the whole point. They run in registration order so
    // one can still depend on the one before it. The future is kept so callers
    // that genuinely depend on a deferred capability can wait for it without
    // the whole application having to.
    _deferredStartup = _startDeferred();
    unawaited(_deferredStartup);
    final requiredError = firstRequiredError;
    _lastInitializationResult = requiredError == null
        ? const KitSuccess<void>(null)
        : KitFailure<void>(requiredError);
    _recomputeHealth(error: requiredError);
    return _lastInitializationResult!;
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    final active = _initialization;
    if (active != null) await active;

    KitError? firstError;
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    for (final module in _modules.values.toList(growable: false).reversed) {
      final result = await module.dispose();
      result.fold(
        onSuccess: (_) {},
        onFailure: (error) => firstError ??= error,
      );
    }
    _modules.clear();
    _disposed = true;
    _setHealth(ModuleState.disposed, error: firstError);
    await _healthChanges.close();
    return firstError == null
        ? const KitSuccess<void>(null)
        : KitFailure<void>(firstError!);
  }

  /// Starts deferred modules sequentially, after startup has been reported.
  Future<void> _startDeferred() async {
    for (final registration
        in _registrations.where((item) => item.enabled && item.isDeferred)) {
      if (_disposed) return;
      StarterModule module;
      try {
        module = registration.create!();
      } on Object catch (error, stackTrace) {
        _recordInitializationError(
          registration,
          KitError(
            code: KitErrorCode.unknown,
            message: 'Deferred module ${registration.moduleId} could not be '
                'created: $error',
            cause: error,
            stackTrace: stackTrace,
          ),
        );
        continue;
      }

      final moduleId = module.moduleId;
      if (moduleId != registration.moduleId &&
          !moduleId.startsWith('${registration.moduleId}.')) {
        _recordInitializationError(
          registration,
          KitError(
            code: KitErrorCode.invalidConfiguration,
            message: 'Registration ${registration.moduleId} created unrelated '
                'module $moduleId.',
          ),
        );
        await module.dispose();
        continue;
      }

      _modules[registration.moduleId] = module;
      _subscriptions[registration.moduleId] = module.healthChanges.listen(
        (health) => _onModuleHealthChanged(registration.moduleId, health),
      );
      _logger.log(
        KitLogLevel.debug,
        'Deferred module initialization started.',
        moduleId: registration.moduleId,
      );

      // No timeout. A deferred module may legitimately wait on a person — a
      // consent form stays open until it is dismissed — and nothing is held up
      // behind it.
      KitResult<void> result;
      try {
        result = await module.initialize();
      } on Object catch (error, stackTrace) {
        result = KitFailure<void>(
          KitError(
            code: KitErrorCode.unknown,
            message: 'Deferred module ${registration.moduleId} threw: $error',
            cause: error,
            stackTrace: stackTrace,
          ),
        );
      }
      result.fold(
        onSuccess: (_) => _logger.log(
          KitLogLevel.info,
          'Deferred module ready.',
          moduleId: registration.moduleId,
        ),
        onFailure: (error) => _recordInitializationError(registration, error),
      );
      if (!_disposed) _recomputeHealth();
    }
  }

  KitError? _validateRegistrations() {
    final ids = <String>{};
    for (final registration in _registrations) {
      final id = registration.moduleId.trim();
      if (id.isEmpty) {
        return const KitError(
          code: KitErrorCode.invalidConfiguration,
          message: 'Starter-kit module IDs must not be empty.',
        );
      }
      if (!ids.add(id)) {
        return KitError(
          code: KitErrorCode.invalidConfiguration,
          message: 'Duplicate starter-kit module ID: $id.',
        );
      }
      if (registration.enabled && registration.create == null) {
        return KitError(
          code: KitErrorCode.invalidConfiguration,
          message: 'Enabled module $id must have a factory.',
        );
      }
    }
    return null;
  }

  void _recordInitializationError(
    StarterModuleRegistration registration,
    KitError error,
  ) {
    _initializationErrors[registration.moduleId] = error;
    _logger.log(
      registration.isRequired ? KitLogLevel.error : KitLogLevel.warning,
      'Starter-kit module initialization failed.',
      moduleId: registration.moduleId,
      error: error,
    );
  }

  void _onModuleHealthChanged(String moduleId, ModuleHealth moduleHealth) {
    if (moduleHealth.isOperational) {
      _initializationErrors.remove(moduleId);
    }
    if (!_initializationInProgress && _initialized && !_disposed) {
      _recomputeHealth();
    }
  }

  void _recomputeHealth({KitError? error}) {
    final requiredIds = _registrations
        .where((item) => item.enabled && item.isRequired)
        .map((item) => item.moduleId)
        .toSet();
    final failedRequired = <String>{};
    final unhealthyOptional = <String>{};
    for (final registration in _registrations.where((item) => item.enabled)) {
      final moduleHealth = _modules[registration.moduleId]?.health;
      final failedAtInitialization =
          _initializationErrors.containsKey(registration.moduleId);
      final unhealthy = failedAtInitialization ||
          moduleHealth == null ||
          !moduleHealth.isOperational;
      final degraded = moduleHealth?.state == ModuleState.degraded;
      if (unhealthy && requiredIds.contains(registration.moduleId)) {
        failedRequired.add(registration.moduleId);
      } else if (unhealthy || degraded) {
        unhealthyOptional.add(registration.moduleId);
      }
    }

    final state = failedRequired.isNotEmpty
        ? ModuleState.failed
        : unhealthyOptional.isNotEmpty
            ? ModuleState.degraded
            : ModuleState.ready;
    _setHealth(
      state,
      error: error ??
          (failedRequired.isEmpty
              ? null
              : _initializationErrors[failedRequired.first]),
      details: <String, Object?>{
        'moduleStates': <String, String>{
          for (final entry in _modules.entries)
            entry.key: entry.value.health.state.name,
        },
        'disabledModuleIds': _registrations
            .where((item) => !item.enabled)
            .map((item) => item.moduleId)
            .toList(growable: false),
        'failedRequiredModuleIds': failedRequired.toList(growable: false),
        'unhealthyOptionalModuleIds': unhealthyOptional.toList(growable: false),
      },
    );
  }

  KitFailure<void> _notReady() => const KitFailure<void>(
        KitError(
          code: KitErrorCode.notInitialized,
          message: 'Starter kit has already been disposed.',
        ),
      );

  void _setHealth(
    ModuleState state, {
    KitError? error,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    _health = ModuleHealth(
      moduleId: moduleId,
      state: state,
      observedAt: _clock.now(),
      error: error,
      details: details,
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
