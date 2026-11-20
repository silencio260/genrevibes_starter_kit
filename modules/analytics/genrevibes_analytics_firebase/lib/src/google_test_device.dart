import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether this phone is one of Google's automated test devices.
///
/// Android only: Firebase Test Lab sets the `firebase.test.lab` system setting
/// on its devices, and Play's pre-launch report and review checks run there.
/// Always false on other platforms, and when the setting can't be read.
///
/// [FirebaseAnalyticsSink] checks this by itself. Hosts call [check] to keep
/// other providers (Mixpanel, PostHog, replay) off these phones as well.
abstract final class GoogleTestDevice {
  static const MethodChannel _channel =
      MethodChannel('com.genrevibes/analytics_firebase');

  static Future<bool>? _result;

  /// Reads the setting once per process; later calls reuse the answer.
  static Future<bool> check() => _result ??= _read();

  /// Replaces the answer, for tests. Pass null to read the device again.
  @visibleForTesting
  static set debugOverride(bool? value) {
    _result = value == null ? null : Future<bool>.value(value);
  }

  static Future<bool> _read() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('isGoogleTestDevice') ?? false;
    } on Object {
      return false;
    }
  }
}
