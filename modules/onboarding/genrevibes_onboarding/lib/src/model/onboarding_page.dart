import 'package:flutter/widgets.dart';

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
}
