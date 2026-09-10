import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:genrevibes_device_identity/genrevibes_device_identity.dart';

const MethodChannel _channel = MethodChannel('com.genrevibes/device_identity');

/// Injectable boundary around the platform vendor identifiers.
abstract interface class VendorIdClient {
  /// Android's app set ID.
  ///
  /// The Android counterpart of iOS's identifierForVendor: shared by every app
  /// from one Play developer account on a device, not resettable by the user,
  /// and documented by Google for analytics and fraud prevention rather than
  /// advertising. It replaced `Build.ID`, which names a firmware build and is
  /// identical on every phone running that build.
  Future<String?> androidAppSetId();

  /// iOS `identifierForVendor`.
  Future<String?> iosVendorId();
}

/// Production client.
final class DefaultVendorIdClient implements VendorIdClient {
  /// Creates a client.
  const DefaultVendorIdClient();

  @override
  Future<String?> androidAppSetId() async {
    final info = await _channel.invokeMapMethod<String, Object?>('appSetId');
    final id = info?['id'];
    return id is String && id.trim().isNotEmpty ? id : null;
  }

  @override
  Future<String?> iosVendorId() async =>
      (await DeviceInfoPlugin().iosInfo).identifierForVendor;
}

/// [VendorIdSource] backed by the platform vendor identifiers.
final class DeviceInfoVendorIdSource implements VendorIdSource {
  /// Creates a source.
  const DeviceInfoVendorIdSource({
    VendorIdClient client = const DefaultVendorIdClient(),
    bool? isAndroid,
    bool? isIos,
  })  : _client = client,
        _isAndroid = isAndroid,
        _isIos = isIos;

  final VendorIdClient _client;
  final bool? _isAndroid;
  final bool? _isIos;

  @override
  Future<String?> vendorId() async {
    if (_isAndroid ?? Platform.isAndroid) return _client.androidAppSetId();
    if (_isIos ?? Platform.isIOS) return _client.iosVendorId();
    return null;
  }
}

/// Identifies this installation of the app, as opposed to the device.
///
/// Android's first-install time. It changes on every reinstall and is not app
/// data, so Auto Backup — which does restore shared preferences — cannot bring
/// it back. State that must not survive a reinstall, such as a passcode
/// lockout, can be tied to it. `null` off Android, where uninstalling removes
/// the app's storage with it.
abstract final class InstallMarker {
  /// Reads the marker, or `null` when it is unavailable.
  static Future<String?> read({bool? isAndroid}) async {
    if (!(isAndroid ?? Platform.isAndroid)) return null;
    try {
      final installedAt = await _channel.invokeMethod<int>('firstInstallTime');
      return installedAt?.toString();
    } on Object {
      return null;
    }
  }
}
