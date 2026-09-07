import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';
import 'package:test/test.dart';

void main() {
  final intervalKey = RemoteConfigKey<int>(
    name: 'ad_interval',
    defaultValue: 3,
    codec: const RemoteConfigIntCodec(),
    isValid: (value) => value >= 0,
  );
  final enabledKey = const RemoteConfigKey<bool>(
    name: 'feature_enabled',
    defaultValue: false,
    codec: RemoteConfigBoolCodec(),
  );
  final schema = RemoteConfigSchema(<RemoteConfigKey<Object?>>[
    remoteConfigKey(intervalKey),
    remoteConfigKey(enabledKey),
  ]);

  test('safe defaults are available before initialization', () {
    final coordinator = RemoteConfigCoordinator(
      schema: schema,
      provider: _FakeProvider(schema),
    );

    expect(coordinator.current.read(intervalKey), 3);
    expect(coordinator.current.read(enabledKey), isFalse);
    expect(
      coordinator.current.originOf(intervalKey),
      RemoteConfigValueOrigin.defaultValue,
    );
  });

  test('loads cache, then lets provider persistence take precedence', () async {
    final provider = _FakeProvider(schema)
      ..currentSnapshot = RemoteConfigProviderSnapshot(
        values: <String, Object?>{'feature_enabled': true},
        origin: RemoteConfigValueOrigin.providerCache,
        observedAt: DateTime(2026),
      );
    final cache = MemoryRemoteConfigCache();
    await cache.write(
      RemoteConfigCacheEntry(
        values: <String, Object?>{'ad_interval': 8},
        storedAt: DateTime(2026),
      ),
    );
    final coordinator = RemoteConfigCoordinator(
      schema: schema,
      provider: provider,
      cache: cache,
    );

    expect((await coordinator.initialize()).isSuccess, isTrue);
    expect(coordinator.current.read(intervalKey), 8);
    expect(coordinator.current.read(enabledKey), isTrue);
    expect(
      coordinator.current.originOf(intervalKey),
      RemoteConfigValueOrigin.cache,
    );
  });

  test('provider defaults do not erase a last-known-good cache on boot',
      () async {
    final provider = _FakeProvider(schema);
    final cache = MemoryRemoteConfigCache();
    await cache.write(
      RemoteConfigCacheEntry(
        values: <String, Object?>{'ad_interval': 8},
        storedAt: DateTime(2026),
      ),
    );
    final coordinator = RemoteConfigCoordinator(
      schema: schema,
      provider: provider,
      cache: cache,
    );

    await coordinator.initialize();

    expect(coordinator.current.read(intervalKey), 8);
    expect(
      coordinator.current.originOf(intervalKey),
      RemoteConfigValueOrigin.cache,
    );
  });

  test('rejects invalid remote values and retains last-known-good values',
      () async {
    final provider = _FakeProvider(schema);
    final coordinator = RemoteConfigCoordinator(
      schema: schema,
      provider: provider,
    );
    await coordinator.initialize();
    provider.nextRefresh = RemoteConfigProviderSnapshot(
      values: <String, Object?>{
        'ad_interval': -4,
        'feature_enabled': true,
      },
      origin: RemoteConfigValueOrigin.remote,
      observedAt: DateTime(2026),
    );

    expect((await coordinator.refresh()).isSuccess, isTrue);
    expect(coordinator.current.read(intervalKey), 3);
    expect(coordinator.current.read(enabledKey), isTrue);
    expect(
      coordinator.current.originOf(intervalKey),
      RemoteConfigValueOrigin.defaultValue,
    );
  });

  test('provider failure keeps current values and reports degraded health',
      () async {
    final provider = _FakeProvider(schema);
    final coordinator = RemoteConfigCoordinator(
      schema: schema,
      provider: provider,
    );
    await coordinator.initialize();
    provider.refreshError = const KitError(
      code: KitErrorCode.network,
      message: 'offline',
    );

    expect((await coordinator.refresh()).isFailure, isTrue);
    expect(coordinator.current.read(intervalKey), 3);
    expect(coordinator.health.state, ModuleState.degraded);
  });
}

final class _FakeProvider implements RemoteConfigProvider {
  _FakeProvider(RemoteConfigSchema schema)
      : currentSnapshot = RemoteConfigProviderSnapshot(
          values: schema.encodedDefaults,
          origin: RemoteConfigValueOrigin.defaultValue,
          observedAt: DateTime(2026),
        ),
        _health = ModuleHealth(
          moduleId: 'remote_config.fake',
          state: ModuleState.idle,
          observedAt: DateTime(2026),
        );

  final StreamController<ModuleHealth> _changes =
      StreamController<ModuleHealth>.broadcast();
  RemoteConfigProviderSnapshot currentSnapshot;
  RemoteConfigProviderSnapshot? nextRefresh;
  KitError? refreshError;
  ModuleHealth _health;

  @override
  RemoteConfigProviderSnapshot get current => currentSnapshot;

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _changes.stream;

  @override
  String get moduleId => 'remote_config.fake';

  @override
  String get providerId => 'fake';

  @override
  Future<KitResult<void>> initialize() async {
    _health = ModuleHealth(
      moduleId: moduleId,
      state: ModuleState.ready,
      observedAt: DateTime(2026),
    );
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<RemoteConfigProviderSnapshot>> refresh() async {
    final error = refreshError;
    if (error != null) return KitFailure<RemoteConfigProviderSnapshot>(error);
    currentSnapshot = nextRefresh ?? currentSnapshot;
    return KitSuccess<RemoteConfigProviderSnapshot>(currentSnapshot);
  }

  @override
  Future<KitResult<void>> dispose() async {
    await _changes.close();
    return const KitSuccess<void>(null);
  }
}
