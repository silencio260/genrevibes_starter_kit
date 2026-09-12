import 'package:flutter/material.dart';

/// How an onboarding flow puts pages, controls and the ad together.
enum OnboardingPresentation {
  /// Every page is a complete screen — its content, its controls and, when it
  /// has one, its own ad — and swipes in as a unit. A page without an ad is a
  /// different screen, not the same screen with something taken out.
  screens,

  /// One set of controls and one ad area under a swiping content area. The ad
  /// area opens and closes as the user moves between pages with and without
  /// an ad.
  sharedControls,
}

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
    this.sizeAnimation = const Duration(milliseconds: 250),
  });

  /// Builds the ad.
  final OnboardingAdBuilder builder;

  /// Where the ad sits.
  final OnboardingAdPosition position;

  /// Whether every page gets its own ad.
  ///
  /// In the shared presentation, whether every page gets its own ad.
  ///
  /// False keeps one ad on screen while the user pages, so it is not reloaded
  /// on every swipe. In the screens presentation every ad page is its own
  /// screen with its own ad, whatever this says.
  final bool oneAdPerPage;

  /// The ad's height, kept on every page that shows an ad from its first
  /// frame, whether or not an ad has loaded.
  ///
  /// The screen is then laid out with the ad's space as part of its design,
  /// and nothing moves when the ad arrives. Match it to the ad, such as
  /// `AppodealNativeAdStyle.resolvedHeight`, and let the ad widget show a
  /// placeholder until it loads. Null sizes the area to the ad, which then
  /// grows into place when it arrives.
  final double? reservedHeight;

  /// How long an ad takes to grow into place when it arrives after its screen
  /// is showing, and, in the shared presentation, how long the ad area takes
  /// to open or close between pages. `Duration.zero` switches at once.
  final Duration sizeAnimation;
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
    this.adFreeControlsPadding,
    this.immersiveScrimColor = const Color(0xCC000000),
    this.immersiveTextColor = const Color(0xFFFFFFFF),
    this.artworkFadeHeight = 0,
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

  /// Padding around the controls of a screen without an ad, in the screens
  /// presentation. Null uses [controlsPadding]. A screen designed around an ad
  /// usually wants its controls tight above it, and one without wants them
  /// where a full-screen page would put them.
  final EdgeInsets? adFreeControlsPadding;

  /// The fade behind the text of an immersive screen.
  final Color immersiveScrimColor;

  /// Title and description color on an immersive screen.
  final Color immersiveTextColor;

  /// Height of the fade from an edge-to-edge screen's artwork into the
  /// background above the title. Zero ends the artwork on a hard edge.
  final double artworkFadeHeight;

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
