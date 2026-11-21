import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Which ad SDKs' own Firebase revenue adapters are compiled into this app.
///
/// Answers per `ad_platform` the kit knows how to look for (today
/// `appodeal`, Appodeal's Firebase service adapter). A platform missing from
/// the map is unknown to the check. Android only: other platforms, and any
/// failure to ask, give an empty map.
///
/// [FirebaseAnalyticsSink] uses it so a platform is skipped at Firebase only
/// when its adapter really is there to send the revenue instead.
abstract final class NativeRevenueAdapters {
  static const MethodChannel _channel =
      MethodChannel('com.genrevibes/analytics_firebase');

  /// Platforms whose adapter the check can find. For these the sink skips
  /// the app's copy only on a positive answer; any other configured platform
  /// is trusted as configured.
  static const Set<String> checkable = {'appodeal'};

  static Future<Map<String, bool>>? _result;

  /// Asks once per process; later calls reuse the answer.
  static Future<Map<String, bool>> check() => _result ??= _read();

  /// Replaces the answer, for tests. Pass null to ask the device again.
  @visibleForTesting
  static set debugOverride(Map<String, bool>? value) {
    _result = value == null ? null : Future<Map<String, bool>>.value(value);
  }

  static Future<Map<String, bool>> _read() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const <String, bool>{};
    }
    try {
      final found =
          await _channel.invokeMapMethod<String, bool>('nativeRevenueAdapters');
      return Map<String, bool>.unmodifiable(found ?? const <String, bool>{});
    } on Object {
      return const <String, bool>{};
    }
  }
}
