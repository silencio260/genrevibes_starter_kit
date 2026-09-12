import 'package:flutter/widgets.dart';

import 'onboarding_flow_options.dart';

/// How `OnboardingFlow` arranges a page as a screen, in the screens
/// presentation.
enum OnboardingScreenLayout {
  /// Content above the controls, and the page's ad, if it has one, below or
  /// above them.
  standard,

  /// Artwork fills the top of the screen edge to edge, under the status bar,
  /// with the title, description and controls below it and the ad, if the
  /// page has one, at the bottom. The artwork takes whatever height the rest
  /// leaves, so a screen without an ad gives it most of the screen and a
  /// screen with one gives it the top half: two finished screens, not one with
  /// a piece missing.
  edgeToEdge,

  /// Artwork edge to edge, with the title, description and controls over a
  /// fade at the bottom. Never shows an ad.
  immersive,
}

/// The pieces a screen builder arranges into one onboarding screen.
final class OnboardingScreenParts {
  /// Creates the parts.
  const OnboardingScreenParts({
    required this.page,
    required this.controls,
    required this.controlsView,
    required this.content,
    this.ad,
  });

  /// The page this screen shows.
  final OnboardingPage page;

  /// State and callbacks for this screen's controls.
  final OnboardingFlowControls controls;

  /// The controls for this screen: the default layout, or the flow's
  /// controls builder.
  final Widget controlsView;

  /// Artwork, title and description, laid out by the page's template or the
  /// flow's page builder.
  final Widget content;

  /// This screen's ad, or null when the page shows none.
  final Widget? ad;
}

/// Arranges an onboarding screen from its [OnboardingScreenParts].
typedef OnboardingScreenBuilder = Widget Function(
  BuildContext context,
  OnboardingScreenParts parts,
);

/// Layout used to render an onboarding page.
enum OnboardingTemplate {
  /// Artwork, title, and description.
  standard,

  /// Title and description only.
  minimal,

  /// A caller-supplied widget.
  custom,
}

/// One page of an onboarding flow.
///
/// Colors are deliberately absent. The view reads them from the ambient theme
/// so onboarding matches the host application, which is what makes this
/// template reusable across a portfolio rather than tied to one app's palette.
final class OnboardingPage {
  /// Creates an onboarding page.
  const OnboardingPage({
    required this.title,
    required this.description,
    this.artwork,
    this.template = OnboardingTemplate.standard,
    this.showAd = true,
    this.layout = OnboardingScreenLayout.standard,
    this.controlsLayout,
    this.screenBuilder,
  });

  /// Headline text.
  final String title;

  /// Supporting text.
  final String description;

  /// Optional artwork.
  ///
  /// A builder rather than an asset path, so this package neither guesses at
  /// asset types nor depends on an animation library. An application that uses
  /// Lottie supplies a Lottie widget here; one that uses images supplies an
  /// `Image`, and neither pays for the other's dependency.
  final WidgetBuilder? artwork;

  /// Layout for this page.
  final OnboardingTemplate template;

  /// Whether `OnboardingFlow` shows its ad slot on this page. Ignored when the
  /// flow has no ad slot, and by `OnboardingView`.
  final bool showAd;

  /// How this page is arranged as a screen, in the screens presentation.
  final OnboardingScreenLayout layout;

  /// This page's control arrangement. Null uses the flow's.
  final OnboardingControlsLayout? controlsLayout;

  /// Arranges this page's whole screen, in the screens presentation. Wins
  /// over the flow's screen builder and [layout].
  final OnboardingScreenBuilder? screenBuilder;
}
