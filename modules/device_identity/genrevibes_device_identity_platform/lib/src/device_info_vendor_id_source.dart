import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:genrevibes_device_identity/genrevibes_device_identity.dart';

/// Injectable boundary around device_info_plus for vendor identifiers.
abstract interface class VendorIdClient {
  /// Android `Build.ID` style identifier.
  Future<String?> androidId();

  /// iOS `identifierForVendor`.
  Future<String?> iosVendorId();
}

/// Production client.
final class DefaultVendorIdClient implements VendorIdClient {
  /// Creates a client.
  const DefaultVendorIdClient();

  @override
  Future<String?> androidId() async =>
      (await DeviceInfoPlugin().androidInfo).id;

  @override
  Future<String?> iosVendorId() async =>
      (await DeviceInfoPlugin().iosInfo).identifierForVendor;
}

/// [VendorIdSource] backed by device_info_plus.
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
    if (_isAndroid ?? Platform.isAndroid) return _client.androidId();
    if (_isIos ?? Platform.isIOS) return _client.iosVendorId();
    return null;
  }
}
