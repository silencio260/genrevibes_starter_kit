import 'package:flutter/foundation.dart';

/// Where a splash is.
enum SplashPhase {
  /// Waiting for the app's work and the ad.
  loading,

  /// The ad is on screen.
  showingAd,

  /// Done; `onFinished` has been called.
  finished,
}

/// What a splash view draws.
@immutable
final class SplashProgress {
  /// Creates progress.
  const SplashProgress({
    required this.value,
    required this.phase,
    required this.adExpected,
  });

  /// From 0 to 1.
  final double value;

  /// Where the splash is.
  final SplashPhase phase;

  /// Whether an ad may follow, for the disclosure.
  final bool adExpected;

  /// [value] as a whole percentage.
  int get percent => (value * 100).clamp(0, 100).round();
}
