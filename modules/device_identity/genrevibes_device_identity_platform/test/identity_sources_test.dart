import 'package:app_tracking_transparency/app_tracking_transparency.dart'
    as att;
import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_device_identity/genrevibes_device_identity.dart';
import 'package:genrevibes_device_identity_platform/genrevibes_device_identity_platform.dart';

void main() {
  group('AttAdvertisingIdSource', () {
    test('maps every plugin status', () {
      for (final status in att.TrackingStatus.values) {
        expect(mapTrackingStatus(status), isA<TrackingAuthorization>());
      }
      expect(mapTrackingStatus(att.TrackingStatus.authorized),
          TrackingAuthorization.authorized);
    });

    test('reports notSupported off iOS without touching the plugin', () async {
      final client = _FakeTracking();
      final source = AttAdvertisingIdSource(client: client, isIos: false);

      expect(await source.requestAuthorization(),
          TrackingAuthorization.notSupported);
      expect(await source.advertisingId(), isNull);
      expect(client.calls, 0);
    });

    test('treats an all-zero identifier as absent', () async {
      final client = _FakeTracking()
        ..id = '00000000-0000-0000-0000-000000000000';
      final source = AttAdvertisingIdSource(client: client, isIos: true);

      expect(await source.advertisingId(), isNull);
    });

    test('returns a real identifier on iOS', () async {
      final client = _FakeTracking()..id = 'ABCD-1234';
      final source = AttAdvertisingIdSource(client: client, isIos: true);

      expect(await source.advertisingId(), 'ABCD-1234');
    });
  });

  group('DeviceInfoVendorIdSource', () {
    test('reads the Android id on Android and the vendor id on iOS', () async {
      final client = _FakeVendor();

      expect(
        await DeviceInfoVendorIdSource(
                client: client, isAndroid: true, isIos: false)
            .vendorId(),
        'android-id',
      );
      expect(
        await DeviceInfoVendorIdSource(
                client: client, isAndroid: false, isIos: true)
            .vendorId(),
        'ios-vendor',
      );
      expect(
        await DeviceInfoVendorIdSource(
                client: client, isAndroid: false, isIos: false)
            .vendorId(),
        isNull,
      );
    });
  });
}

final class _FakeTracking implements TrackingClient {
  String id = '';
  int calls = 0;
  @override
  Future<att.TrackingStatus> status() async {
    calls++;
    return att.TrackingStatus.notDetermined;
  }

  @override
  Future<att.TrackingStatus> request() async {
    calls++;
    return att.TrackingStatus.authorized;
  }

  @override
  Future<String> advertisingIdentifier() async {
    calls++;
    return id;
  }
}

final class _FakeVendor implements VendorIdClient {
  @override
  Future<String?> androidId() async => 'android-id';
  @override
  Future<String?> iosVendorId() async => 'ios-vendor';
}
