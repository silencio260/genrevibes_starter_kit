import 'package:flutter/material.dart';

/// What the skip control does.
enum OnboardingSkipBehavior {
  /// No skip control.
  hidden,

  /// Jumps to the last page, so its content and its ad are still seen.
  jumpToLastPage,

  /// Runs the skip actions, or the finish actions when there are none.
  finish,
}

/// How the progress indicator and buttons are arranged.
enum OnboardingControlsLayout {
  /// Skip, indicator and Next in one row, and a full-width button on the last
  /// page.
  row,

  /// The indicator above a centered Next text button, which keeps the bottom
  /// of the screen free for an ad.
  stacked,

  /// The indicator above a full-width button on every page.
  fullWidthButton,
}

/// Where an ad sits in an onboarding flow.
enum OnboardingAdPosition {
  /// Below the controls, at the bottom of the screen.
  bottom,

  /// Between the page content and the controls.
  aboveControls,
}

/// Builds the ad for the page at [pageIndex].
typedef OnboardingAdBuilder = Widget Function(
  BuildContext context,
  int pageIndex,
);

/// An ad shown inside an onboarding flow.
///
/// Onboarding knows nothing about ad networks: [builder] returns whatever
/// renders one, such as `AppodealNativeAdView`. Eligibility onboarding cannot
/// see — premium, consent, a remote switch — belongs to the builder, or to
/// whether a slot is passed at all.
final class OnboardingAdSlot {
  /// Creates an ad slot.
  const OnboardingAdSlot({
    required this.builder,
    this.position = OnboardingAdPosition.bottom,
    this.oneAdPerPage = false,
    this.reservedHeight,
  });

  /// Builds the ad.
  final OnboardingAdBuilder builder;

  /// Where the ad sits.
  final OnboardingAdPosition position;

  /// Whether every page gets its own ad.
  ///
  /// False keeps one ad on screen while the user pages, so it is not reloaded
  /// on every swipe. A page with `showAd: false` removes it, and the next page
  /// that shows one builds a new ad.
  final bool oneAdPerPage;

  /// Height kept free for the ad before it loads, so content does not jump
  /// when it arrives. Null takes only the space the ad uses.
  final double? reservedHeight;
}

/// Visual overrides for an onboarding flow. Anything null comes from the
/// ambient theme.
final class OnboardingFlowStyle {
  /// Creates a style.
  const OnboardingFlowStyle({
    this.backgroundColor,
    this.titleStyle,
    this.descriptionStyle,
    this.activeIndicatorColor,
    this.inactiveIndicatorColor,
    this.buttonStyle,
    this.textButtonStyle,
    this.skipButtonStyle,
    this.pagePadding = const EdgeInsets.symmetric(horizontal: 24),
    this.controlsPadding = const EdgeInsets.fromLTRB(24, 12, 24, 16),
    this.artworkFlex = 3,
    this.textFlex = 2,
    this.textSpacing = 12,
    this.pageTransitionDuration = const Duration(milliseconds: 300),
    this.pageTransitionCurve = Curves.easeInOut,
  });

  /// Background behind the whole flow.
  final Color? backgroundColor;

  /// Page title style.
  final TextStyle? titleStyle;

  /// Page description style.
  final TextStyle? descriptionStyle;

  /// Current page dot.
  final Color? activeIndicatorColor;

  /// Other page dots.
  final Color? inactiveIndicatorColor;

  /// The full-width button.
  final ButtonStyle? buttonStyle;

  /// The Next text button.
  final ButtonStyle? textButtonStyle;

  /// The skip button.
  final ButtonStyle? skipButtonStyle;

  /// Padding around each page's content.
  final EdgeInsets pagePadding;

  /// Padding around the controls.
  final EdgeInsets controlsPadding;

  /// Share of a page's height given to artwork.
  final int artworkFlex;

  /// Share of a page's height given to the title and description.
  final int textFlex;

  /// Space between artwork, title and description.
  final double textSpacing;

  /// How long moving to another page takes.
  final Duration pageTransitionDuration;

  /// The curve of that movement.
  final Curve pageTransitionCurve;
}

/// Labels for the flow's controls.
final class OnboardingLabels {
  /// Creates labels.
  const OnboardingLabels({
    this.next = 'Next',
    this.skip = 'Skip',
    this.finish = 'Get started',
  });

  /// Advances to the next page.
  final String next;

  /// The skip control.
  final String skip;

  /// Finishes the flow, on the last page.
  final String finish;
}

/// What a custom controls builder can read and do.
final class OnboardingFlowControls {
  /// Creates the controls state.
  const OnboardingFlowControls({
    required this.pageIndex,
    required this.pageCount,
    required this.busy,
    required this.next,
    required this.finish,
    required this.goTo,
    this.skip,
  });

  /// The visible page.
  final int pageIndex;

  /// How many pages there are.
  final int pageCount;

  /// Whether finish or skip actions are running. Buttons should disable.
  final bool busy;

  /// Whether the visible page is the last.
  bool get isLastPage => pageIndex == pageCount - 1;

  /// Moves to the next page, or finishes on the last.
  final VoidCallback next;

  /// Runs the finish actions.
  final VoidCallback finish;

  /// Moves to the page at an index.
  final ValueChanged<int> goTo;

  /// Skips, or null when skipping is hidden.
  final VoidCallback? skip;
}
