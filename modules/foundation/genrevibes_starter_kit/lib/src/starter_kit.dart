import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';
import 'starter_module_registration.dart';

/// Starts only selected modules. Failed or timed-out optional work never blocks
/// the next module; a timeout does not invent a successful provider result.
final class GenRevibesStarterKit implements StarterModule {
  GenRevibesStarterKit({
    required Iterable<StarterModuleRegistration> modules,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
    Duration moduleTimeout = const Duration(seconds: 10),
    this.autoStartDeferred = true,
  })  : _registrations = List.unmodifiable(modules),
        _clock = clock,
        _logger = logger,
        _moduleTimeout = moduleTimeout,
        _health = ModuleHealth(
            moduleId: 'starter_kit',
            state: ModuleState.idle,
            observedAt: clock.now());

  /// Hosts with UI call startDeferred after their first frame instead.
  final bool autoStartDeferred;
  final List<StarterModuleRegistration> _registrations;
  final KitClock _clock;
  final KitLogger _logger;
  final Duration _moduleTimeout;
  final Map<String, StarterModule> _modules = {};
  final Map<String, StreamSubscription<ModuleHealth>> _subscriptions = {};
  final Map<String, KitError> _initializationErrors = {};
  final StreamController<ModuleHealth> _healthChanges =
      StreamController.broadcast();
  late ModuleHealth _health;
  Future<KitResult<void>>? _initialization;
  Future<KitResult<void>>? _disposal;
  KitResult<void>? _lastInitializationResult;
  final Completer<void> _stopped = Completer<void>();
  final Completer<void> _deferredComplete = Completer<void>();
  Future<void>? _deferredStartup;
  bool _initializationInProgress = false;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => 'starter_kit';
  @override
  ModuleHealth get health => _health;
  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;
  Map<String, StarterModule> get modules => Map.unmodifiable(_modules);
  List<String> get registeredModuleIds =>
      List.unmodifiable(_registrations.map((r) => r.moduleId));

  /// Completes after all deferred attempts, including failures/timeouts, or stop.
  /// Inspect moduleHealth for the outcome. Manual hosts must call startDeferred.
  Future<void> get deferredStartupComplete =>
      _registrations.any((r) => r.enabled && r.isDeferred)
          ? _deferredComplete.future
          : Future<void>.value();

  ModuleHealth? moduleHealth(String id) {
    final current = _modules[id]?.health;
    final error = _initializationErrors[id];
    if (error == null) {
      if (current != null) return current;
      for (final registration in _registrations) {
        if (registration.moduleId == id) {
          return ModuleHealth(
              moduleId: id,
              state: _disposed
                  ? ModuleState.disposed
                  : registration.enabled
                      ? ModuleState.idle
                      : ModuleState.disabled,
              observedAt: _clock.now(),
              message: registration.enabled
                  ? 'Waiting to start'
                  : 'Disabled by this app');
        }
      }
      return null;
    }
    return ModuleHealth(
        moduleId: id,
        provider: current?.provider,
        state: ModuleState.failed,
        observedAt: _clock.now(),
        error: error,
        details: current?.details ?? const {});
  }

  T? module<T extends StarterModule>(String id) {
    final value = _modules[id];
    return value is T ? value : null;
  }

  @override
  Future<KitResult<void>> initialize() {
    if (_disposed) return Future.value(_notReady());
    if (_initialized) return Future.value(_lastInitializationResult!);
    return _initialization ??= _initializeOnce();
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
    KitError? requiredError;
    for (final registration
        in _registrations.where((r) => r.enabled && !r.isDeferred)) {
      if (_disposed) break;
      final result = await _start(registration);
      if (registration.isRequired) {
        result.fold(
            onSuccess: (_) {}, onFailure: (error) => requiredError ??= error);
      }
    }
    _initializationInProgress = false;
    if (_disposed) return _notReady();
    _initialized = true;
    _lastInitializationResult = requiredError == null
        ? const KitSuccess<void>(null)
        : KitFailure<void>(requiredError!);
    _recomputeHealth(error: requiredError);
    if (autoStartDeferred) unawaited(startDeferred());
    return _lastInitializationResult!;
  }

  /// Idempotent. A deferred failure never prevents the next module starting.
  Future<void> startDeferred() => _deferredStartup ??= _startDeferred();

  Future<void> _startDeferred() async {
    try {
      await initialize();
      if (_validateRegistrations() != null) return;
      for (final registration
          in _registrations.where((r) => r.enabled && r.isDeferred)) {
        if (_disposed) break;
        await _start(registration);
        if (!_disposed) _recomputeHealth();
      }
    } finally {
      if (!_deferredComplete.isCompleted) _deferredComplete.complete();
    }
  }

  Future<KitResult<void>> _start(StarterModuleRegistration registration) async {
    StarterModule? created;
    KitResult<void> result;
    try {
      final module = registration.create!();
      created = module;
      if (module.moduleId != registration.moduleId &&
          !module.moduleId.startsWith('${registration.moduleId}.')) {
        await _disposeModule(module);
        throw StateError(
            'Registration ${registration.moduleId} created unrelated module ${module.moduleId}.');
      }
      if (_disposed) {
        await _disposeModule(module);
        return _notReady();
      }
      _modules[registration.moduleId] = module;
      _subscriptions[registration.moduleId] = module.healthChanges.listen(
          (health) => _onModuleHealthChanged(registration.moduleId, health));
      _logger.log(KitLogLevel.debug, 'Module initialization started.',
          moduleId: registration.moduleId);
      final work = module.initialize();
      // Native operations may be uncancellable. Clean up again if one finishes
      // after stop, and never let its callback restart the remaining sequence.
      unawaited(work.then<void>((_) async {
        if (_disposed) await _disposeModule(module);
      }, onError: (Object _, StackTrace __) {}));
      result = await Future.any<KitResult<void>>([
        work.timeout(registration.timeout ?? _moduleTimeout,
            onTimeout: () => KitFailure<void>(KitError(
                code: KitErrorCode.timeout,
                message: 'Module ${registration.moduleId} timed out.'))),
        _stopped.future.then((_) => _notReady()),
      ]);
    } on Object catch (error, stack) {
      result = KitFailure<void>(KitError(
          code: created != null &&
                  created.moduleId != registration.moduleId &&
                  !created.moduleId.startsWith('${registration.moduleId}.')
              ? KitErrorCode.invalidConfiguration
              : KitErrorCode.unknown,
          message: 'Module ${registration.moduleId} could not start.',
          cause: error,
          stackTrace: stack));
    }
    if (_disposed) return _notReady();
    result.fold(
        onSuccess: (_) => _logger.log(KitLogLevel.info, 'Module ready.',
            moduleId: registration.moduleId),
        onFailure: (error) => _recordInitializationError(registration, error));
    return result;
  }

  Future<KitResult<void>> _disposeModule(StarterModule module) async {
    try {
      return await module.dispose().timeout(_moduleTimeout);
    } on Object catch (error, stack) {
      return KitFailure<void>(KitError(
          code: error is TimeoutException
              ? KitErrorCode.timeout
              : KitErrorCode.unknown,
          message: 'Module ${module.moduleId} cleanup failed.',
          cause: error,
          stackTrace: stack));
    }
  }

  @override
  Future<KitResult<void>> dispose() {
    if (_disposal != null) return _disposal!;
    _disposed = true;
    if (!_stopped.isCompleted) _stopped.complete();
    if (!_deferredComplete.isCompleted) _deferredComplete.complete();
    return _disposal = _dispose();
  }

  Future<KitResult<void>> _dispose() async {
    KitError? firstError;
    for (final subscription in _subscriptions.values.toList()) {
      try {
        await subscription.cancel().timeout(_moduleTimeout);
      } on Object catch (error) {
        firstError ??= KitError(
            code: KitErrorCode.unknown,
            message: 'Listener cleanup failed.',
            cause: error);
      }
    }
    _subscriptions.clear();
    for (final module in _modules.values.toList().reversed) {
      final result = await _disposeModule(module);
      result.fold(
          onSuccess: (_) {}, onFailure: (error) => firstError ??= error);
    }
    _modules.clear();
    _setHealth(ModuleState.disposed, error: firstError);
    await _healthChanges.close();
    return firstError == null
        ? const KitSuccess<void>(null)
        : KitFailure<void>(firstError!);
  }

  KitError? _validateRegistrations() {
    if (_moduleTimeout <= Duration.zero ||
        _registrations
            .any((r) => r.timeout != null && r.timeout! <= Duration.zero)) {
      return const KitError(
          code: KitErrorCode.invalidConfiguration,
          message: 'Module timeouts must be positive.');
    }
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
    if (_disposed) return;
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
            entry.key: moduleHealth(entry.key)!.state.name,
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
