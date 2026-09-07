import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_permissions/genrevibes_permissions.dart';
import 'package:genrevibes_permissions_handler/genrevibes_permissions_handler.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

void main() {
  group('mapping', () {
    test('every neutral kind maps to a plugin permission', () {
      for (final kind in PermissionKind.values) {
        expect(permissionFor(kind), isA<ph.Permission>(), reason: '$kind');
      }
    });

    test('every plugin status maps to a neutral state', () {
      for (final status in ph.PermissionStatus.values) {
        expect(mapPermissionStatus(status), isNot(PermissionState.unknown));
      }
      expect(mapPermissionStatus(ph.PermissionStatus.permanentlyDenied),
          PermissionState.permanentlyDenied);
    });
  });

  group('PermissionHandlerProvider', () {
    test('loads platform facts at initialization', () async {
      final provider = _provider(_FakeClient(), sdk: 34);

      await provider.initialize();

      expect(provider.platform.hasSplitMediaPermissions, isTrue);
      expect(provider.health.state, ModuleState.ready);
    });

    test('rejects work before initialization', () async {
      final result =
          await _provider(_FakeClient()).check(PermissionKind.photos);

      expect(
        result.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
        KitErrorCode.notInitialized,
      );
    });

    test('checks and requests through the client', () async {
      final client = _FakeClient()
        ..statuses[ph.Permission.camera] = ph.PermissionStatus.denied
        ..onRequest[ph.Permission.camera] = ph.PermissionStatus.granted;
      final provider = _provider(client);
      await provider.initialize();

      final before = await provider.check(PermissionKind.camera);
      final after = await provider.request(PermissionKind.camera);

      expect(_v(before), PermissionState.denied);
      expect(_v(after), PermissionState.granted);
    });

    test('a plugin fault becomes a provider error and degrades health',
        () async {
      final client = _FakeClient()..failWith = StateError('no activity');
      final provider = _provider(client);
      await provider.initialize();

      final result = await provider.request(PermissionKind.photos);

      expect(
        result.fold(onSuccess: (_) => null, onFailure: (e) => e.providerCode),
        'permission_handler_request',
      );
      expect(provider.health.state, ModuleState.degraded);
    });

    test('unavailable platform facts still let the provider start', () async {
      final provider = PermissionHandlerProvider(
        client: _FakeClient(),
        platformFacts: _ThrowingFacts(),
      );

      expect((await provider.initialize()).isSuccess, isTrue);
      expect(provider.platform.hasSplitMediaPermissions, isFalse);
    });

    test('composes with the coordinator end to end', () async {
      final client = _FakeClient()
        ..statuses[ph.Permission.photos] = ph.PermissionStatus.denied
        ..onRequest[ph.Permission.photos] = ph.PermissionStatus.granted;
      final coordinator = PermissionCoordinator(
        provider: _provider(client, sdk: 33),
        store: MemoryKeyValueStore(),
      );
      await coordinator.initialize();
      final kinds = const MediaPermissionPolicy()
          .mediaKindsFor(coordinator.provider.platform);

      final result = await coordinator.request(kinds);

      expect(
        result.fold(onSuccess: (r) => r.isGranted, onFailure: (_) => false),
        isFalse,
        reason: 'videos and audio were never granted',
      );
      expect(client.requested, contains(ph.Permission.videos));
    });
  });
}

PermissionState? _v(KitResult<PermissionState> r) =>
    r.fold(onSuccess: (v) => v, onFailure: (_) => null);

PermissionHandlerProvider _provider(_FakeClient client, {int sdk = 33}) {
  return PermissionHandlerProvider(
    client: client,
    platformFacts: _FixedFacts(
      PlatformFacts(isAndroid: true, isIos: false, androidSdkInt: sdk),
    ),
  );
}

final class _FixedFacts implements PlatformFactsSource {
  const _FixedFacts(this.facts);
  final PlatformFacts facts;
  @override
  Future<PlatformFacts> load() async => facts;
}

final class _ThrowingFacts implements PlatformFactsSource {
  @override
  Future<PlatformFacts> load() async => throw StateError('no device info');
}

final class _FakeClient implements PermissionHandlerClient {
  final Map<ph.Permission, ph.PermissionStatus> statuses = {};
  final Map<ph.Permission, ph.PermissionStatus> onRequest = {};
  final List<ph.Permission> requested = <ph.Permission>[];
  Object? failWith;

  @override
  Future<ph.PermissionStatus> status(ph.Permission permission) async {
    if (failWith != null) throw failWith!;
    return statuses[permission] ?? ph.PermissionStatus.denied;
  }

  @override
  Future<ph.PermissionStatus> request(ph.Permission permission) async {
    if (failWith != null) throw failWith!;
    requested.add(permission);
    final next = onRequest[permission] ??
        statuses[permission] ??
        ph.PermissionStatus.denied;
    statuses[permission] = next;
    return next;
  }

  @override
  Future<bool> openAppSettings() async => true;
}
