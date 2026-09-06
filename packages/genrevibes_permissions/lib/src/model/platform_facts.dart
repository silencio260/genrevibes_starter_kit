/// The few platform facts permission policy depends on.
///
/// A value object rather than `dart:io` calls, so policy is testable for every
/// Android level and both platforms from one test file.
final class PlatformFacts {
  /// Creates platform facts.
  const PlatformFacts({
    required this.isAndroid,
    required this.isIos,
    this.androidSdkInt,
  });

  /// Android.
  final bool isAndroid;

  /// iOS.
  final bool isIos;

  /// Android API level, or `null` when not Android or unknown.
  final int? androidSdkInt;

  /// Android 13 (API 33) or newer, where media permissions are split.
  bool get hasSplitMediaPermissions => isAndroid && (androidSdkInt ?? 0) >= 33;
}
