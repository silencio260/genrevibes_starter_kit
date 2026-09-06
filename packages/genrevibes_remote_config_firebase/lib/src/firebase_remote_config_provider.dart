import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';

import 'firebase_remote_config_client.dart';
import 'firebase_remote_config_configuration.dart';

/// Firebase implementation of the GenRevibes remote-config provider contract.
final class GenRevibesFirebaseRemoteConfigProvider
    implements RemoteConfigProvider {
  /// Creates a Firebase Remote Config provider.
  GenRevibesFirebaseRemoteConfigProvider({
    required RemoteConfigSchema schema,
    GenRevibesFirebaseRemoteConfigConfiguration configuration =
        const GenRevibesFirebaseRemoteConfigConfiguration(),
    FirebaseRemoteConfigClient? client,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _schema = schema,
        _configuration = configuration,
        _client = client ?? DefaultFirebaseRemoteConfigClient(),
        _clock = clock,
        _logger = logger,
        _current = RemoteConfigProviderSnapshot(
          values: <String, Object?>{
            for (final key in schema.keys) key.name: key.defaultValue,
          },
          origin: RemoteConfigValueOrigin.defaultValue,
          observedAt: clock.now(),
        ),
        _health = ModuleHealth(
          moduleId: 'remote_config.firebase',
          provider: 'firebase',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final RemoteConfigSchema _schema;
  final GenRevibesFirebaseRemoteConfigConfiguration _configuration;
  final FirebaseRemoteConfigClient _client;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  late RemoteConfigProviderSnapshot _current;
  late ModuleHealth _health;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => 'remote_config.firebase';

  @override
  String get providerId => 'firebase';

  @override
  RemoteConfigProviderSnapshot get current => _current;

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  Future<KitResult<void>> initialize() async {
    if (_initialized) return const KitSuccess<void>(null);
    if (_disposed) return _notReady<void>();
    final configurationError = _validateConfiguration();
    if (configurationError != null) {
      _setHealth(ModuleState.failed, error: configurationError);
      return KitFailure<void>(configurationError);
    }
    _setHealth(ModuleState.initializing);
    try {
      await _client.setup(_configuration, _schema.encodedDefaults);
      _current = _read(RemoteConfigValueOrigin.providerCache);
      _initialized = true;
      _setHealth(ModuleState.ready);
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      final mapped = _mapError(error, stackTrace);
      _setHealth(ModuleState.failed, error: mapped);
      _logFailure('Firebase Remote Config initialization failed.', mapped);
      return KitFailure<void>(mapped);
    }
  }

  @override
  Future<KitResult<RemoteConfigProviderSnapshot>> refresh() async {
    if (!_initialized || _disposed) {
      return _notReady<RemoteConfigProviderSnapshot>();
    }
    try {
      await _client.fetchAndActivate();
      _current = _read(RemoteConfigValueOrigin.remote);
      _setHealth(ModuleState.ready);
      return KitSuccess<RemoteConfigProviderSnapshot>(_current);
    } on Object catch (error, stackTrace) {
      final mapped = _mapError(error, stackTrace);
      _setHealth(ModuleState.degraded, error: mapped);
      _logFailure(
        'Firebase Remote Config fetch failed; activated values remain valid.',
        mapped,
      );
      return KitFailure<RemoteConfigProviderSnapshot>(mapped);
    }
  }

  RemoteConfigProviderSnapshot _read(RemoteConfigValueOrigin remoteOrigin) {
    final read = _client.read(_schema, remoteOrigin: remoteOrigin);
    return RemoteConfigProviderSnapshot(
      values: read.values,
      origins: read.origins,
      origin: remoteOrigin,
      observedAt: _clock.now(),
    );
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

  KitError? _validateConfiguration() {
    if (_configuration.fetchTimeout <= Duration.zero ||
        _configuration.minimumFetchInterval.isNegative) {
      return const KitError(
        code: KitErrorCode.invalidConfiguration,
        message: 'Firebase fetch durations must not be negative or zero.',
      );
    }
    return null;
  }

  KitError _mapError(Object error, StackTrace stackTrace) {
    if (error is FirebaseException) {
      return KitError(
        code: _firebaseCode(error.code),
        message:
            'Firebase Remote Config failed: ${error.message ?? error.code}',
        providerCode: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return KitError(
      code: KitErrorCode.provider,
      message: 'Firebase Remote Config failed: $error',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  KitErrorCode _firebaseCode(String code) {
    final normalized = code.toLowerCase();
    if (normalized.contains('timeout') || normalized.contains('throttl')) {
      return KitErrorCode.timeout;
    }
    if (normalized.contains('network')) return KitErrorCode.network;
    return KitErrorCode.provider;
  }

  KitFailure<T> _notReady<T>() {
    return KitFailure<T>(
      const KitError(
        code: KitErrorCode.notInitialized,
        message: 'Firebase Remote Config has not been initialized.',
      ),
    );
  }

  void _logFailure(String message, KitError error) {
    _logger.log(
      KitLogLevel.warning,
      message,
      moduleId: moduleId,
      error: error,
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
