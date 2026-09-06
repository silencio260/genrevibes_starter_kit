import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_device_identity/genrevibes_device_identity.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';
import 'package:test/test.dart';

void main() {
  group('SecureUuidGenerator', () {
    test('produces distinct RFC 4122 v4 identifiers', () {
      const generator = SecureUuidGenerator();
      final a = generator.generate();
      final b = generator.generate();

      expect(a, isNot(b));
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(a),
        isTrue,
      );
    });
  });

  group('DeviceIdentityResolver', () {
    test('generates and persists an install id on first run', () async {
      final store = MemoryKeyValueStore();
      final resolver = DeviceIdentityResolver(
        store: store,
        generator: _FixedGenerator('install-1'),
      );

      await resolver.initialize();

      expect(resolver.current!.installId, 'install-1');
      expect(store.values[DeviceIdentityKeys.installId], 'install-1');
    });

    test('reuses the persisted install id across instances', () async {
      final store = MemoryKeyValueStore();
      await DeviceIdentityResolver(
        store: store,
        generator: _FixedGenerator('first'),
      ).initialize();

      final second = DeviceIdentityResolver(
        store: store,
        generator: _FixedGenerator('second'),
      );
      await second.initialize();

      expect(second.current!.installId, 'first');
    });

    test('adopts a legacy device_uuid so analytics continuity survives',
        () async {
      final delegate = MemoryKeyValueStore(
        initialValues: {'device_uuid': 'legacy-abc'},
      );
      final resolver = DeviceIdentityResolver(
        store: MigratingKeyValueStore(
          delegate: delegate,
          legacyKeys: DeviceIdentityKeys.legacyKeys,
        ),
        generator: _FixedGenerator('fresh'),
      );

      await resolver.initialize();

      expect(resolver.current!.installId, 'legacy-abc');
    });

    test('does not prompt for tracking at initialization', () async {
      final advertising = _FakeAdvertising();
      final resolver = DeviceIdentityResolver(
        store: MemoryKeyValueStore(),
        advertising: advertising,
      );

      await resolver.initialize();

      expect(advertising.prompted, isFalse);
      expect(resolver.current!.tracking, TrackingAuthorization.notDetermined);
      expect(resolver.current!.advertisingId, isNull);
    });

    test('prompts on demand and reads the advertising id when authorized',
        () async {
      final advertising = _FakeAdvertising()
        ..onRequest = TrackingAuthorization.authorized
        ..id = 'IDFA-1';
      final resolver = DeviceIdentityResolver(
        store: MemoryKeyValueStore(),
        advertising: advertising,
      );
      await resolver.initialize();

      final result = await resolver.resolve(promptTracking: true);

      final identity =
          result.fold(onSuccess: (v) => v, onFailure: (_) => null)!;
      expect(advertising.prompted, isTrue);
      expect(identity.canTrack, isTrue);
      expect(identity.advertisingId, 'IDFA-1');
    });

    test('never reads the advertising id when denied', () async {
      final advertising = _FakeAdvertising()
        ..onRequest = TrackingAuthorization.denied
        ..id = 'IDFA-1';
      final resolver = DeviceIdentityResolver(
        store: MemoryKeyValueStore(),
        advertising: advertising,
      );
      await resolver.initialize();

      final result = await resolver.resolve(promptTracking: true);

      expect(
        result.fold(onSuccess: (v) => v.advertisingId, onFailure: (_) => 'x'),
        isNull,
      );
    });

    test('a failing platform source yields null instead of failing', () async {
      final resolver = DeviceIdentityResolver(
        store: MemoryKeyValueStore(),
        vendor: _ThrowingVendor(),
      );

      final result = await resolver.initialize();

      expect(result.isSuccess, isTrue);
      expect(resolver.current!.vendorId, isNull);
      expect(resolver.health.state, ModuleState.ready);
    });

    test('unwritable storage fails loudly rather than inventing an id',
        () async {
      final resolver = DeviceIdentityResolver(store: _BrokenStore());

      final result = await resolver.initialize();

      expect(result.isFailure, isTrue);
      expect(resolver.health.state, ModuleState.failed);
    });

    test('emits each resolved identity', () async {
      final resolver = DeviceIdentityResolver(store: MemoryKeyValueStore());
      final seen = <DeviceIdentity>[];
      resolver.changes.listen(seen.add);

      await resolver.initialize();
      await resolver.resolve();
      await Future<void>.delayed(Duration.zero);

      expect(seen, hasLength(2));
    });
  });
}

final class _FixedGenerator implements InstallIdGenerator {
  const _FixedGenerator(this.value);
  final String value;
  @override
  String generate() => value;
}

final class _FakeAdvertising implements AdvertisingIdSource {
  TrackingAuthorization onRequest = TrackingAuthorization.notDetermined;
  String? id;
  bool prompted = false;
  TrackingAuthorization _current = TrackingAuthorization.notDetermined;

  @override
  Future<TrackingAuthorization> authorization() async => _current;

  @override
  Future<TrackingAuthorization> requestAuthorization() async {
    prompted = true;
    _current = onRequest;
    return _current;
  }

  @override
  Future<String?> advertisingId() async => id;
}

final class _ThrowingVendor implements VendorIdSource {
  @override
  Future<String?> vendorId() async => throw StateError('no plugin');
}

final class _BrokenStore implements KeyValueStore {
  static const _error = KitError(code: KitErrorCode.provider, message: 'disk');
  @override
  Future<KitResult<bool?>> getBool(String key) async =>
      const KitFailure(_error);
  @override
  Future<KitResult<int?>> getInt(String key) async => const KitFailure(_error);
  @override
  Future<KitResult<String?>> getString(String key) async =>
      const KitFailure(_error);
  @override
  Future<KitResult<List<String>?>> getStringList(String key) async =>
      const KitFailure(_error);
  @override
  Future<KitResult<void>> setBool(String key, bool value) async =>
      const KitFailure(_error);
  @override
  Future<KitResult<void>> setInt(String key, int value) async =>
      const KitFailure(_error);
  @override
  Future<KitResult<void>> setString(String key, String value) async =>
      const KitFailure(_error);
  @override
  Future<KitResult<void>> setStringList(String key, List<String> value) async =>
      const KitFailure(_error);
  @override
  Future<KitResult<void>> remove(String key) async => const KitFailure(_error);
}
