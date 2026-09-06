import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:genrevibes_permissions/genrevibes_permissions.dart';

/// Loads [PlatformFacts] at startup.
abstract interface class PlatformFactsSource {
  /// Reads the facts once.
  Future<PlatformFacts> load();
}

/// Production source over `dart:io` and device_info_plus.
final class DeviceInfoPlatformFactsSource implements PlatformFactsSource {
  /// Creates a source.
  const DeviceInfoPlatformFactsSource();

  @override
  Future<PlatformFacts> load() async {
    final isAndroid = Platform.isAndroid;
    final isIos = Platform.isIOS;
    int? sdkInt;
    if (isAndroid) {
      sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    }
    return PlatformFacts(
      isAndroid: isAndroid,
      isIos: isIos,
      androidSdkInt: sdkInt,
    );
  }
}
