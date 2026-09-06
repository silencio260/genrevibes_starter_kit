import 'dart:async';
import 'dart:convert';

import 'package:genrevibes_analytics/genrevibes_analytics.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

import 'firebase_analytics_client.dart';

/// Firebase implementation of the GenRevibes analytics sink contract.
final class FirebaseAnalyticsSink implements AnalyticsSink {
  /// Creates a Firebase Analytics sink.
  FirebaseAnalyticsSink({
    FirebaseAnalyticsClient? client,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _client = client ?? DefaultFirebaseAnalyticsClient(),
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'analytics.firebase',
          provider: 'firebase',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final FirebaseAnalyticsClient _client;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  late ModuleHealth _health;
  bool _initialized = false;
  bool _disposed = false;

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  String get moduleId => 'analytics.firebase';

  @override
  String get sinkId => 'firebase';

  @override
  Future<KitResult<void>> initialize() async {
    if (_initialized) return const KitSuccess<void>(null);
    if (_disposed) return _notReady();
    if (!_client.isFirebaseInitialized) {
      return _failure(
        KitErrorCode.invalidConfiguration,
        'Firebase must be initialized by the host application first.',
        updateHealth: true,
      );
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
    if (event.name.trim().isEmpty) {
      return Future<KitResult<void>>.value(
        _failure(
          KitErrorCode.invalidConfiguration,
          'Analytics event names must not be empty.',
        ),
      );
    }
    return _guard(
      () => _client.logEvent(
        event.name.trim(),
        sanitizeFirebaseParameters(event.properties),
      ),
    );
  }

  @override
  Future<KitResult<void>> identify(AnalyticsUser user) async {
    if (user.id.trim().isEmpty) {
      return _failure(
        KitErrorCode.invalidConfiguration,
        'Analytics user IDs must not be empty.',
      );
    }
    final identified = await _guard(() => _client.setUserId(user.id.trim()));
    if (identified.isFailure) return identified;
    return setUserProperties(user.properties);
  }

  @override
  Future<KitResult<void>> setUserProperties(
    Map<String, Object?> properties,
  ) {
    return _guard(() async {
      for (final entry in properties.entries) {
        await _client.setUserProperty(
          entry.key,
          firebaseUserPropertyValue(entry.value),
        );
      }
    });
  }

  @override
  Future<KitResult<void>> resetIdentity() {
    return _guard(() async {
      await _client.setUserId(null);
      await _client.resetAnalyticsData();
    });
  }

  @override
  Future<KitResult<void>> flush() async {
    final notReady = _requireReady();
    return notReady ?? const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _initialized = false;
    _disposed = true;
    _setHealth(ModuleState.disposed);
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  Future<KitResult<void>> _guard(Future<void> Function() operation) async {
    final notReady = _requireReady();
    if (notReady != null) return notReady;
    try {
      await operation();
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      _logger.log(
        KitLogLevel.warning,
        'Firebase Analytics operation failed.',
        moduleId: moduleId,
        error: error,
        stackTrace: stackTrace,
      );
      return KitFailure<void>(
        KitError(
          code: KitErrorCode.provider,
          message: 'Firebase Analytics operation failed: $error',
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
        message: 'Firebase Analytics has not been initialized.',
      ),
    );
  }

  KitFailure<void> _failure(
    KitErrorCode code,
    String message, {
    bool updateHealth = false,
  }) {
    final failure = KitFailure<void>(KitError(code: code, message: message));
    if (updateHealth) _setHealth(ModuleState.failed, error: failure.error);
    return failure;
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

/// Converts neutral properties into values accepted by Firebase Analytics.
Map<String, Object>? sanitizeFirebaseParameters(
  Map<String, Object?> properties,
) {
  if (properties.isEmpty) return null;
  return <String, Object>{
    for (final entry in properties.entries)
      if (entry.value != null) entry.key: _firebaseValue(entry.value!),
  };
}

Object _firebaseValue(Object value) {
  return switch (value) {
    String() || int() || double() => value,
    bool() => value ? 1 : 0,
    DateTime() => value.toUtc().toIso8601String(),
    _ => jsonEncode(value),
  };
}

/// Converts a neutral profile value into Firebase's string property format.
String? firebaseUserPropertyValue(Object? value) {
  if (value == null) return null;
  return switch (value) {
    String() => value,
    DateTime() => value.toUtc().toIso8601String(),
    _ => value.toString(),
  };
}
