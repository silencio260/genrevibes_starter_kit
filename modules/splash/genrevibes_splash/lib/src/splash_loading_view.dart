import 'package:flutter/material.dart';

import 'splash_progress.dart';
import 'splash_style.dart';

/// The default splash: logo and title in the upper part of the screen, and at
/// the bottom a progress line, a rounded bar and, while an ad may follow, the
/// ad disclosure.
class SplashLoadingView extends StatelessWidget {
  /// Creates the view.
  const SplashLoadingView({
    required this.progress,
    super.key,
    this.logo,
    this.title,
    this.background,
    this.style = const SplashLoadingStyle(),
    this.labels = const SplashLabels(),
  });

  /// What to draw.
  final SplashProgress progress;

  /// The app's logo.
  final Widget? logo;

  /// The app's name.
  final String? title;

  /// Fills the screen behind the content, such as a full-bleed image.
  final Widget? background;

  /// Colors and sizes.
  final SplashLoadingStyle style;

  /// Text.
  final SplashLabels labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = style.progressColor ?? theme.colorScheme.primary;
    final background = this.background;
    final logo = this.logo;
    final title = this.title;

    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: style.backgroundColor,
          gradient: style.backgroundGradient,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (background != null) background,
            SafeArea(
              child: Padding(
                padding: style.contentPadding,
                child: Column(
                  children: <Widget>[
                    const Spacer(flex: 2),
                    if (logo != null) logo,
                    if (title != null) ...<Widget>[
                      SizedBox(height: style.logoSpacing),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: style.titleStyle ??
                            theme.textTheme.headlineMedium?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                    const Spacer(flex: 3),
                    Text(
                      labels.progressText(progress.percent),
                      style: style.progressLabelStyle ??
                          theme.textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF3C4043),
                          ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(style.progressHeight),
                      child: LinearProgressIndicator(
                        value: progress.value,
                        minHeight: style.progressHeight,
                        color: accent,
                        backgroundColor: style.progressTrackColor ??
                            accent.withValues(alpha: 0.18),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedOpacity(
                      opacity: progress.adExpected ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        labels.adDisclosure,
                        textAlign: TextAlign.center,
                        style: style.disclosureStyle ??
                            theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF5F6368),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
