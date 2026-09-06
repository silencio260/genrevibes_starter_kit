import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

import 'mixpanel_replay_client.dart';
import 'mixpanel_replay_configuration.dart';

/// Lifecycle and privacy controls for the optional Mixpanel replay SDK.
final class MixpanelReplayController implements StarterModule {
  /// Creates a replay controller.
  MixpanelReplayController({
    required GenRevibesMixpanelReplayConfiguration configuration,
    MixpanelReplayClient? client,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  }) : _configuration = configuration,
       _client = client ?? DefaultMixpanelReplayClient(),
       _clock = clock,
       _logger = logger,
       _health = ModuleHealth(
         moduleId: 'analytics.mixpanel.replay',
         provider: 'mixpanel',
         state: ModuleState.idle,
         observedAt: clock.now(),
       );

  final GenRevibesMixpanelReplayConfiguration _configuration;
  final MixpanelReplayClient _client;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  late ModuleHealth _health;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => 'analytics.mixpanel.replay';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  /// Wraps [child] in the replay recorder. The wrapper is inert before setup.
  Widget wrap(Widget child) => _client.wrap(child);

  @override
  Future<KitResult<void>> initialize() async {
    if (_initialized) return const KitSuccess<void>(null);
    if (_disposed) return _notReady();
    final configurationError = _validateConfiguration();
    if (configurationError != null) {
      _setHealth(ModuleState.failed, error: configurationError);
      return KitFailure<void>(configurationError);
    }
    _setHealth(ModuleState.initializing);
    final result = await _guard(
      () => _client.setup(_configuration),
      requireInitialized: false,
    );
    if (result.isFailure) {
      final error = result.fold(onSuccess: (_) => null, onFailure: (e) => e);
      _setHealth(ModuleState.failed, error: error);
      return result;
    }
    _initialized = true;
    _setHealth(ModuleState.ready);
    return const KitSuccess<void>(null);
  }

  /// Starts recording. Call only after analytics consent is granted.
  Future<KitResult<void>> start() {
    return _guard(
      () => _client.start(sessionsPercent: _configuration.sessionsPercent),
    );
  }

  /// Immediately stops capture for private or secure application surfaces.
  Future<KitResult<void>> stop() => _guard(_client.stop);

  /// Keeps replay identity aligned with the events SDK identity.
  Future<KitResult<void>> identify(String distinctId) {
    if (distinctId.trim().isEmpty) {
      return Future<KitResult<void>>.value(
        const KitFailure<void>(
          KitError(
            code: KitErrorCode.invalidConfiguration,
            message: 'Mixpanel replay distinct ID must not be empty.',
          ),
        ),
      );
    }
    return _guard(() => _client.identify(distinctId.trim()));
  }

  /// Flushes queued replay data.
  Future<KitResult<void>> flush() => _guard(_client.flush);

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    if (_initialized) {
      await _guard(_client.stop);
      await _guard(_client.flush);
    }
    _initialized = false;
    _disposed = true;
    _setHealth(ModuleState.disposed);
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  KitError? _validateConfiguration() {
    if (_configuration.token.trim().isEmpty ||
        _configuration.distinctId.trim().isEmpty) {
      return const KitError(
        code: KitErrorCode.invalidConfiguration,
        message: 'Mixpanel replay token and distinct ID must not be empty.',
      );
    }
    if (_configuration.sessionsPercent < 0 ||
        _configuration.sessionsPercent > 100) {
      return const KitError(
        code: KitErrorCode.invalidConfiguration,
        message: 'Mixpanel replay percentage must be between 0 and 100.',
      );
    }
    if (_configuration.storageQuotaMb < 1) {
      return const KitError(
        code: KitErrorCode.invalidConfiguration,
        message: 'Mixpanel replay storage quota must be positive.',
      );
    }
    return null;
  }

  Future<KitResult<void>> _guard(
    Future<void> Function() operation, {
    bool requireInitialized = true,
  }) async {
    if (requireInitialized && (!_initialized || _disposed)) {
      return _notReady();
    }
    try {
      await operation();
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      _logger.log(
        KitLogLevel.warning,
        'Mixpanel replay operation failed.',
        moduleId: moduleId,
        error: error,
        stackTrace: stackTrace,
      );
      return KitFailure<void>(
        KitError(
          code: KitErrorCode.provider,
          message: 'Mixpanel replay operation failed: $error',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  KitFailure<void> _notReady() {
    return const KitFailure<void>(
      KitError(
        code: KitErrorCode.notInitialized,
        message: 'Mixpanel replay has not been initialized.',
      ),
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: 'mixpanel',
      state: state,
      observedAt: _clock.now(),
      error: error,
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
