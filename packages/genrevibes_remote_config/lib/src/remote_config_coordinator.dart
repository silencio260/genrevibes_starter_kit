import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';

import 'remote_config_cache.dart';
import 'remote_config_provider.dart';
import 'remote_config_schema.dart';
import 'remote_config_snapshot.dart';

/// Applies schema validation, safe defaults, and last-known-good retention.
final class RemoteConfigCoordinator implements StarterModule {
  /// Creates a provider-neutral remote-config coordinator.
  RemoteConfigCoordinator({
    required RemoteConfigSchema schema,
    required RemoteConfigProvider provider,
    RemoteConfigCache? cache,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _schema = schema,
        _provider = provider,
        _cache = cache ?? MemoryRemoteConfigCache(),
        _clock = clock,
        _logger = logger,
        _current = _defaults(schema, clock.now()),
        _health = ModuleHealth(
          moduleId: 'remote_config',
          provider: provider.providerId,
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final RemoteConfigSchema _schema;
  final RemoteConfigProvider _provider;
  final RemoteConfigCache _cache;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  final StreamController<RemoteConfigSnapshot> _changes =
      StreamController<RemoteConfigSnapshot>.broadcast();
  late ModuleHealth _health;
  RemoteConfigSnapshot _current;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => 'remote_config';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  /// Current safe snapshot. Defaults are available before initialization.
  RemoteConfigSnapshot get current => _current;

  /// Emits every accepted cache or provider snapshot.
  Stream<RemoteConfigSnapshot> get changes => _changes.stream;

  @override
  Future<KitResult<void>> initialize() async {
    if (_initialized) return const KitSuccess<void>(null);
    if (_disposed) return _notReady<void>();
    _setHealth(ModuleState.initializing);
    var degraded = false;

    final cached = await _cache.read();
    cached.fold(
      onSuccess: (entry) {
        if (entry != null) {
          _accept(entry.values, RemoteConfigValueOrigin.cache);
        }
      },
      onFailure: (error) {
        degraded = true;
        _logFailure('Remote-config cache read failed.', error);
      },
    );

    final initialized = await _provider.initialize();
    initialized.fold(
      onSuccess: (_) {
        _acceptProvider(_provider.current, allowDefaultOverride: false);
      },
      onFailure: (error) {
        degraded = true;
        _logFailure('Remote-config provider initialization failed.', error);
      },
    );

    _initialized = true;
    _setHealth(degraded ? ModuleState.degraded : ModuleState.ready);
    return const KitSuccess<void>(null);
  }

  /// Fetches new values while retaining each previous valid value on failure.
  Future<KitResult<RemoteConfigSnapshot>> refresh() async {
    if (!_initialized || _disposed) return _notReady<RemoteConfigSnapshot>();
    final result = await _provider.refresh();
    if (result.isFailure) {
      final error = result.fold(onSuccess: (_) => null, onFailure: (e) => e)!;
      _setHealth(ModuleState.degraded, error: error);
      _logFailure(
          'Remote-config refresh failed; retaining safe values.', error);
      return KitFailure<RemoteConfigSnapshot>(error);
    }

    final providerSnapshot = result.fold(
      onSuccess: (snapshot) => snapshot,
      onFailure: (_) => throw StateError('Unreachable failed result.'),
    );
    _acceptProvider(providerSnapshot, allowDefaultOverride: true);
    final cacheResult = await _cache.write(
      RemoteConfigCacheEntry(values: _current.values, storedAt: _clock.now()),
    );
    KitError? cacheError;
    cacheResult.fold(
      onSuccess: (_) {},
      onFailure: (error) {
        cacheError = error;
        _logFailure('Remote-config cache write failed.', error);
      },
    );
    _setHealth(
      cacheError == null ? ModuleState.ready : ModuleState.degraded,
      error: cacheError,
    );
    return KitSuccess<RemoteConfigSnapshot>(_current);
  }

  void _accept(
    Map<String, Object?> candidates,
    RemoteConfigValueOrigin origin, {
    Map<String, RemoteConfigValueOrigin> candidateOrigins =
        const <String, RemoteConfigValueOrigin>{},
    bool allowDefaultOverride = true,
  }) {
    final values = Map<String, Object?>.of(_current.values);
    final acceptedOrigins =
        Map<String, RemoteConfigValueOrigin>.of(_current.origins);
    for (final key in _schema.keys) {
      if (!candidates.containsKey(key.name)) continue;
      final candidateOrigin = candidateOrigins[key.name] ?? origin;
      final currentOrigin = acceptedOrigins[key.name];
      if (!allowDefaultOverride &&
          candidateOrigin == RemoteConfigValueOrigin.defaultValue &&
          currentOrigin != RemoteConfigValueOrigin.defaultValue) {
        continue;
      }
      final accepted = key.tryDecode(candidates[key.name]);
      if (accepted == null) {
        _logger.log(
          KitLogLevel.warning,
          'Rejected invalid remote-config value.',
          moduleId: moduleId,
          fields: <String, Object?>{'key': key.name, 'origin': origin.name},
        );
        continue;
      }
      values[key.name] = accepted;
      acceptedOrigins[key.name] = candidateOrigin;
    }
    _current = RemoteConfigSnapshot(
      values: values,
      origins: acceptedOrigins,
      observedAt: _clock.now(),
    );
    if (!_changes.isClosed) _changes.add(_current);
  }

  void _acceptProvider(
    RemoteConfigProviderSnapshot snapshot, {
    required bool allowDefaultOverride,
  }) {
    _accept(
      snapshot.values,
      snapshot.origin,
      candidateOrigins: snapshot.origins,
      allowDefaultOverride: allowDefaultOverride,
    );
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    final providerResult = await _provider.dispose();
    _initialized = false;
    _disposed = true;
    _setHealth(ModuleState.disposed);
    await _changes.close();
    await _healthChanges.close();
    return providerResult;
  }

  void _logFailure(String message, KitError error) {
    _logger.log(
      KitLogLevel.warning,
      message,
      moduleId: moduleId,
      error: error,
    );
  }

  KitFailure<T> _notReady<T>() {
    return KitFailure<T>(
      const KitError(
        code: KitErrorCode.notInitialized,
        message: 'Remote config has not been initialized.',
      ),
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: _provider.providerId,
      state: state,
      observedAt: _clock.now(),
      error: error,
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }

  static RemoteConfigSnapshot _defaults(
    RemoteConfigSchema schema,
    DateTime observedAt,
  ) {
    return RemoteConfigSnapshot(
      values: <String, Object?>{
        for (final key in schema.keys) key.name: key.defaultValue,
      },
      origins: <String, RemoteConfigValueOrigin>{
        for (final key in schema.keys)
          key.name: RemoteConfigValueOrigin.defaultValue,
      },
      observedAt: observedAt,
    );
  }
}
