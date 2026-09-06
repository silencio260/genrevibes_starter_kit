import 'dart:async';

import 'package:genrevibes_analytics/genrevibes_analytics.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

import 'posthog_analytics_client.dart';
import 'posthog_configuration.dart';

/// PostHog implementation of the GenreVibes analytics sink contract.
final class PostHogAnalyticsSink implements AnalyticsSink {
  /// Creates a PostHog analytics sink.
  PostHogAnalyticsSink({
    required GenreVibesPostHogConfiguration configuration,
    PostHogAnalyticsClient? client,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _configuration = configuration,
        _client = client ?? DefaultPostHogAnalyticsClient(),
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'analytics.posthog',
          provider: 'posthog',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final GenreVibesPostHogConfiguration _configuration;
  final PostHogAnalyticsClient _client;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  late ModuleHealth _health;
  bool _initialized = false;
  bool _disposed = false;
  String? _currentUserId;

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  String get moduleId => 'analytics.posthog';

  @override
  String get sinkId => 'posthog';

  @override
  Future<KitResult<void>> initialize() async {
    if (_initialized) return const KitSuccess<void>(null);
    if (_disposed) return _notReady();
    if (_configuration.apiKey.trim().isEmpty ||
        _configuration.host.trim().isEmpty) {
      const error = KitError(
        code: KitErrorCode.invalidConfiguration,
        message: 'PostHog API key and host must not be empty.',
      );
      _setHealth(ModuleState.failed, error: error);
      return const KitFailure<void>(error);
    }
    _setHealth(ModuleState.initializing);
    final result = await _guard(
      () => _client.setup(_configuration.toSdkConfiguration()),
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
    return _guard(enabled ? _client.enable : _client.disable);
  }

  @override
  Future<KitResult<void>> track(AnalyticsEvent event) {
    if (event.name.trim().isEmpty) {
      return Future<KitResult<void>>.value(
        const KitFailure<void>(
          KitError(
            code: KitErrorCode.invalidConfiguration,
            message: 'Analytics event names must not be empty.',
          ),
        ),
      );
    }
    return _guard(
      () => _client.capture(
        event.name.trim(),
        sanitizePostHogProperties(event.properties),
      ),
    );
  }

  @override
  Future<KitResult<void>> identify(AnalyticsUser user) async {
    if (user.id.trim().isEmpty) {
      return const KitFailure<void>(
        KitError(
          code: KitErrorCode.invalidConfiguration,
          message: 'Analytics user IDs must not be empty.',
        ),
      );
    }
    final userId = user.id.trim();
    final result = await _guard(
      () => _client.identify(
        userId,
        sanitizePostHogProperties(user.properties),
      ),
    );
    if (result.isSuccess) _currentUserId = userId;
    return result;
  }

  @override
  Future<KitResult<void>> setUserProperties(
    Map<String, Object?> properties,
  ) {
    final userId = _currentUserId;
    if (userId == null) {
      return Future<KitResult<void>>.value(
        const KitFailure<void>(
          KitError(
            code: KitErrorCode.invalidConfiguration,
            message: 'Identify a PostHog user before setting properties.',
          ),
        ),
      );
    }
    return _guard(
      () => _client.identify(userId, sanitizePostHogProperties(properties)),
    );
  }

  @override
  Future<KitResult<void>> resetIdentity() async {
    final result = await _guard(_client.reset);
    if (result.isSuccess) _currentUserId = null;
    return result;
  }

  @override
  Future<KitResult<void>> flush() => _guard(_client.flush);

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    if (_initialized) await _client.close();
    _initialized = false;
    _disposed = true;
    _currentUserId = null;
    _setHealth(ModuleState.disposed);
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  Future<KitResult<void>> _guard(
    Future<void> Function() operation, {
    bool requireInitialized = true,
  }) async {
    if (requireInitialized) {
      final notReady = _requireReady();
      if (notReady != null) return notReady;
    }
    try {
      await operation();
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      _logger.log(
        KitLogLevel.warning,
        'PostHog operation failed.',
        moduleId: moduleId,
        error: error,
        stackTrace: stackTrace,
      );
      return KitFailure<void>(
        KitError(
          code: KitErrorCode.provider,
          message: 'PostHog operation failed: $error',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  KitFailure<void>? _requireReady() {
    return _initialized && !_disposed ? null : _notReady();
  }

  KitFailure<void> _notReady() {
    return const KitFailure<void>(
      KitError(
        code: KitErrorCode.notInitialized,
        message: 'PostHog has not been initialized.',
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

/// Removes null values while preserving PostHog-compatible property values.
Map<String, Object>? sanitizePostHogProperties(
  Map<String, Object?> properties,
) {
  if (properties.isEmpty) return null;
  return <String, Object>{
    for (final entry in properties.entries)
      if (entry.value != null) entry.key: entry.value!,
  };
}
