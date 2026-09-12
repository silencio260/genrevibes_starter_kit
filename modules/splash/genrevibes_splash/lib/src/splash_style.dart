import 'package:flutter/painting.dart';

/// Text on the default splash.
final class SplashLabels {
  /// Creates labels.
  const SplashLabels({
    this.loading = 'Loading',
    this.adDisclosure = 'This action can contain ads',
    this.progress,
  });

  /// The word before the percentage.
  final String loading;

  /// Shown under the bar while an ad may follow.
  final String adDisclosure;

  /// Formats the progress line. Null gives `Loading 42%...`.
  final String Function(int percent)? progress;

  /// The progress line for [percent].
  String progressText(int percent) =>
      progress?.call(percent) ?? '$loading $percent%...';
}

/// The look of the default splash.
final class SplashLoadingStyle {
  /// Creates a style.
  const SplashLoadingStyle({
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.backgroundGradient,
    this.titleStyle,
    this.progressColor,
    this.progressTrackColor,
    this.progressHeight = 10,
    this.progressLabelStyle,
    this.disclosureStyle,
    this.contentPadding = const EdgeInsets.fromLTRB(32, 0, 32, 32),
    this.logoSpacing = 24,
  });

  /// Background behind everything.
  final Color backgroundColor;

  /// Painted over [backgroundColor] when set.
  final Gradient? backgroundGradient;

  /// The title. Null uses the theme's headline in [progressColor].
  final TextStyle? titleStyle;

  /// The bar, and the default title color. Null uses the theme's primary.
  final Color? progressColor;

  /// Behind the bar. Null uses a pale [progressColor].
  final Color? progressTrackColor;

  /// The bar's thickness.
  final double progressHeight;

  /// The progress line.
  final TextStyle? progressLabelStyle;

  /// The ad disclosure.
  final TextStyle? disclosureStyle;

  /// Space around the content.
  final EdgeInsets contentPadding;

  /// Space between the logo and the title.
  final double logoSpacing;
}
