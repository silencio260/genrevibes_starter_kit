import 'package:flutter/material.dart';

/// Dots showing which onboarding page is visible, the current one stretched.
final class OnboardingPageIndicator extends StatelessWidget {
  /// Creates an indicator.
  const OnboardingPageIndicator({
    required this.count,
    required this.activeIndex,
    super.key,
    this.activeColor,
    this.inactiveColor,
    this.dotSize = 8,
    this.activeWidth = 24,
    this.spacing = 4,
  });

  /// How many pages there are.
  final int count;

  /// The visible page.
  final int activeIndex;

  /// Current dot color. Defaults to the theme's primary color.
  final Color? activeColor;

  /// Other dots. Defaults to the theme's outline variant.
  final Color? inactiveColor;

  /// Dot height, and width of the other dots.
  final double dotSize;

  /// Width of the current dot.
  final double activeWidth;

  /// Space between dots.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var index = 0; index < count; index++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.symmetric(horizontal: spacing / 2),
            height: dotSize,
            width: index == activeIndex ? activeWidth : dotSize,
            decoration: BoxDecoration(
              color: index == activeIndex
                  ? activeColor ?? scheme.primary
                  : inactiveColor ?? scheme.outlineVariant,
              borderRadius: BorderRadius.circular(dotSize / 2),
            ),
          ),
      ],
    );
  }
}
