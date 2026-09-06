import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_crash/genrevibes_crash.dart';

import 'crashlytics_client.dart';

/// Firebase Crashlytics implementation of [CrashReporter].
final class CrashlyticsReporter implements CrashReporter {
  /// Creates a Crashlytics reporter.
  CrashlyticsReporter({
    CrashlyticsClient client = const DefaultCrashlyticsClient(),
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _client = client,
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'crash.crashlytics',
          provider: 'crashlytics',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final CrashlyticsClient _client;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  ModuleHealth _health;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get providerId => 'crashlytics';

  @override
  String get moduleId => 'crash.crashlytics';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  Future<KitResult<void>> initialize() async {
    if (_disposed) return _notReady<void>();
    if (_initialized) return const KitSuccess<void>(null);
    // Crashlytics needs no explicit start beyond Firebase.initializeApp, which
    // the application owns. Readiness here means "the client can be called".
    _initialized = true;
    _setHealth(ModuleState.ready);
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> setCollectionEnabled(bool enabled) {
    return _guard(
      () => _client.setCrashlyticsCollectionEnabled(enabled),
      'set_collection_enabled',
    );
  }

  @override
  Future<KitResult<void>> setUserIdentifier(String identifier) {
    return _guard(
      () => _client.setUserIdentifier(identifier),
      'set_user_identifier',
    );
  }

  @override
  Future<KitResult<void>> setCustomKey(String key, Object value) {
    return _guard(() => _client.setCustomKey(key, value), 'set_custom_key');
  }

  @override
  Future<KitResult<void>> record(CrashReport report) {
    return _guard(() {
      final error = report.error;
      // A framework payload carries library, context and the widget stack;
      // routing it through recordFlutterError keeps all of that.
      if (error is FlutterErrorDetails) {
        return _client.recordFlutterError(error, fatal: report.fatal);
      }
      return _client.recordError(
        error,
        report.stackTrace,
        reason: report.reason,
        information: <Object>[
          'source: ${report.source.name}',
          for (final entry in report.information.entries)
            '${entry.key}: ${entry.value}',
        ],
        fatal: report.fatal,
      );
    }, 'record');
  }

  @override
  Future<KitResult<void>> log(String message) {
    return _guard(() => _client.log(message), 'log');
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _disposed = true;
    _setHealth(ModuleState.disposed);
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  Future<KitResult<void>> _guard(
    Future<void> Function() action,
    String providerCode,
  ) async {
    if (!_initialized || _disposed) return _notReady<void>();
    try {
      await action();
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      final mapped = KitError(
        code: KitErrorCode.provider,
        message: 'Crashlytics $providerCode failed: $error',
        providerCode: 'crashlytics_$providerCode',
        cause: error,
        stackTrace: stackTrace,
      );
      _logger.log(
        KitLogLevel.warning,
        'Crashlytics operation failed.',
        moduleId: moduleId,
        error: mapped,
      );
      if (!_disposed) _setHealth(ModuleState.degraded, error: mapped);
      return KitFailure<void>(mapped);
    }
  }

  KitFailure<T> _notReady<T>() {
    return KitFailure<T>(
      const KitError(
        code: KitErrorCode.notInitialized,
        message: 'Crashlytics reporter has not been initialized.',
      ),
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: providerId,
      state: state,
      observedAt: _clock.now(),
      error: error,
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
