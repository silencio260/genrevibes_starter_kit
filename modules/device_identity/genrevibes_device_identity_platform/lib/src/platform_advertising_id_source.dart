import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:genrevibes_device_identity/genrevibes_device_identity.dart';

import 'att_advertising_id_source.dart';

const MethodChannel _channel = MethodChannel('com.genrevibes/device_identity');

/// Google's advertising ID as Google Play services reports it.
final class AndroidAdvertisingIdInfo {
  /// Creates a reading.
  const AndroidAdvertisingIdInfo({
    required this.id,
    required this.limitAdTracking,
  });

  /// The ID, or all zeros when the user deleted it.
  final String? id;

  /// Whether the user opted out of ad personalisation.
  final bool limitAdTracking;
}

/// Injectable boundary around Google's advertising ID.
abstract interface class AndroidAdvertisingIdClient {
  /// Reads the advertising ID from Google Play services.
  Future<AndroidAdvertisingIdInfo> read();
}

/// Production client, over this package's Android plugin.
final class DefaultAndroidAdvertisingIdClient
    implements AndroidAdvertisingIdClient {
  /// Creates a client.
  const DefaultAndroidAdvertisingIdClient();

  @override
  Future<AndroidAdvertisingIdInfo> read() async {
    final info =
        await _channel.invokeMapMethod<String, Object?>('advertisingId');
    final id = info?['id'];
    return AndroidAdvertisingIdInfo(
      id: id is String ? id : null,
      limitAdTracking: info?['limitAdTracking'] == true,
    );
  }
}

/// [AdvertisingIdSource] for both platforms: Google's advertising ID on
/// Android, and App Tracking Transparency's IDFA on iOS.
///
/// Android has no prompt. The ID counts as authorized unless the user deleted
/// it (Play services then returns zeros) or opted out of ad personalisation;
/// either is reported as `denied` with no ID, so an opt-out is honoured rather
/// than read around.
///
/// Meant for developer tools, to register a phone as an ad test device.
/// Resolving it into `DeviceIdentity` would make it part of what an app
/// reports.
final class PlatformAdvertisingIdSource implements AdvertisingIdSource {
  /// Creates a source.
  const PlatformAdvertisingIdSource({
    AndroidAdvertisingIdClient android =
        const DefaultAndroidAdvertisingIdClient(),
    AdvertisingIdSource ios = const AttAdvertisingIdSource(),
    bool? isAndroid,
  })  : _android = android,
        _ios = ios,
        _isAndroid = isAndroid;

  final AndroidAdvertisingIdClient _android;
  final AdvertisingIdSource _ios;
  final bool? _isAndroid;

  bool get _onAndroid => _isAndroid ?? Platform.isAndroid;

  @override
  Future<TrackingAuthorization> authorization() async {
    if (!_onAndroid) return _ios.authorization();
    return await _androidId() == null
        ? TrackingAuthorization.denied
        : TrackingAuthorization.authorized;
  }

  @override
  Future<TrackingAuthorization> requestAuthorization() async {
    if (!_onAndroid) return _ios.requestAuthorization();
    return authorization();
  }

  @override
  Future<String?> advertisingId() async {
    if (!_onAndroid) return _ios.advertisingId();
    return _androidId();
  }

  Future<String?> _androidId() async {
    final info = await _android.read();
    final id = info.id;
    if (info.limitAdTracking || id == null || _zeros.hasMatch(id)) return null;
    return id;
  }

  // Also matches an empty ID.
  static final RegExp _zeros = RegExp(r'^[0-]*$');
}
