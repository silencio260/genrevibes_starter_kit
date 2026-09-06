import 'dart:async';

import 'package:genrevibes_analytics/genrevibes_analytics.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

import 'mixpanel_analytics_client.dart';
import 'mixpanel_configuration.dart';

/// Mixpanel implementation of the GenreVibes analytics sink contract.
final class MixpanelAnalyticsSink implements AnalyticsSink {
  /// Creates a Mixpanel analytics sink.
  MixpanelAnalyticsSink({
    required GenreVibesMixpanelConfiguration configuration,
    MixpanelAnalyticsClient? client,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _configuration = configuration,
        _client = client ?? DefaultMixpanelAnalyticsClient(),
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'analytics.mixpanel',
          provider: 'mixpanel',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final GenreVibesMixpanelConfiguration _configuration;
  final MixpanelAnalyticsClient _client;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  late ModuleHealth _health;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => 'analytics.mixpanel';

  @override
  String get sinkId => 'mixpanel';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

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

  @override
  Future<KitResult<void>> setCollectionEnabled(bool enabled) {
    return _guard(() => _client.setCollectionEnabled(enabled));
  }

  @override
  Future<KitResult<void>> track(AnalyticsEvent event) {
    final name = event.name.trim();
    if (name.isEmpty) {
      return Future<KitResult<void>>.value(
        const KitFailure<void>(
          KitError(
            code: KitErrorCode.invalidConfiguration,
            message: 'Analytics event names must not be empty.',
          ),
        ),
      );
    }
    final properties = sanitizeMixpanelProperties(event.properties);
    if (event.occurredAt != null) {
      properties[r'$time'] = event.occurredAt!.millisecondsSinceEpoch / 1000;
    }
    return _guard(
      () => _client.track(name, properties.isEmpty ? null : properties),
    );
  }

  @override
  Future<KitResult<void>> identify(AnalyticsUser user) async {
    final userId = user.id.trim();
    if (userId.isEmpty) {
      return const KitFailure<void>(
        KitError(
          code: KitErrorCode.invalidConfiguration,
          message: 'Analytics user IDs must not be empty.',
        ),
      );
    }
    final identified = await _guard(() => _client.identify(userId));
    if (identified.isFailure || user.properties.isEmpty) return identified;
    return _guard(
      () => _client.setPeopleProperties(
        sanitizeMixpanelProperties(user.properties),
      ),
    );
  }

  @override
  Future<KitResult<void>> setUserProperties(
    Map<String, Object?> properties,
  ) {
    return _guard(
      () => _client.setPeopleProperties(sanitizeMixpanelProperties(properties)),
    );
  }

  @override
  Future<KitResult<void>> resetIdentity() => _guard(_client.reset);

  @override
  Future<KitResult<void>> flush() => _guard(_client.flush);

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    if (_initialized) await _client.flush();
    _initialized = false;
    _disposed = true;
    _setHealth(ModuleState.disposed);
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  KitError? _validateConfiguration() {
    if (_configuration.token.trim().isEmpty) {
      return const KitError(
        code: KitErrorCode.invalidConfiguration,
        message: 'Mixpanel token must not be empty.',
      );
    }
    final batchSize = _configuration.flushBatchSize;
    if (batchSize != null && (batchSize < 1 || batchSize > 50)) {
      return const KitError(
        code: KitErrorCode.invalidConfiguration,
        message: 'Mixpanel flush batch size must be between 1 and 50.',
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
        'Mixpanel operation failed.',
        moduleId: moduleId,
        error: error,
        stackTrace: stackTrace,
      );
      return KitFailure<void>(
        KitError(
          code: KitErrorCode.provider,
          message: 'Mixpanel operation failed: $error',
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
        message: 'Mixpanel has not been initialized.',
      ),
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: sinkId,
      state: state,
      observedAt: _clock.now(),
      error: error,
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}

/// Removes null values before passing properties to Mixpanel.
Map<String, Object> sanitizeMixpanelProperties(
  Map<String, Object?> properties,
) {
  return <String, Object>{
    for (final entry in properties.entries)
      if (entry.value != null) entry.key: entry.value!,
  };
}
