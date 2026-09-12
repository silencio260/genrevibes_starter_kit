import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Shows or hides the phone's system navigation bar: the back, home and recents
/// buttons, or the gesture handle.
abstract interface class SystemNavigationBar {
  /// Whether this platform lets the app hide the navigation bar.
  bool get isSupported;

  /// Shows or hides the navigation bar.
  ///
  /// Hidden, a swipe from the bottom edge shows it for a moment and it hides
  /// again by itself.
  Future<void> setVisible(bool visible);
}

/// The navigation bar through this package's Android plugin.
///
/// Every other platform reports [isSupported] as false and ignores
/// [setVisible].
final class PlatformSystemNavigationBar implements SystemNavigationBar {
  /// Creates the platform navigation bar.
  const PlatformSystemNavigationBar();

  static const MethodChannel _channel = MethodChannel(
    'com.genrevibes/system_ui',
  );

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> setVisible(bool visible) async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>(
      'setNavigationBarVisible',
      <String, Object?>{'visible': visible},
    );
  }
}
