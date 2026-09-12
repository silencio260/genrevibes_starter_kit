import 'package:flutter/widgets.dart';

/// How the app asks before Back closes it.
///
/// A style with an ad — [adSheet], [adDialog], or [featuresSheet] when given
/// one — puts an ad on the way out of the app. Google Play's ads policy lists
/// "Ads that are triggered by the home button or other features explicitly
/// designed for exiting the app" as disruptive, so ship those knowingly.
enum ExitPromptStyle {
  /// A bottom sheet with a native ad above a full-width Exit bar.
  adSheet('ad_sheet', needsAd: true, usesAd: true),

  /// A dialog with a title, a native ad, and Exit and Cancel.
  adDialog('ad_dialog', needsAd: true, usesAd: true),

  /// A tall sheet with the app's features in a carousel, a native ad when one
  /// is given, and the exit question.
  featuresSheet('features_sheet', usesAd: true),

  /// A sheet with one offer, such as premium, and Exit under it.
  offerSheet('offer_sheet'),

  /// A dialog with a title, a message, and Exit and Cancel.
  confirmDialog('confirm_dialog'),

  /// Back twice within a short window, with a hint after the first.
  doubleTap('double_tap'),

  /// Back closes the app at once.
  none('none');

  const ExitPromptStyle(
    this.wireName, {
    this.needsAd = false,
    this.usesAd = false,
  });

  /// The name in remote config and analytics.
  final String wireName;

  /// Whether this style cannot show without an ad.
  final bool needsAd;

  /// Whether this style shows an ad when given one, so one is worth preloading.
  final bool usesAd;

  /// The style named [value], or null.
  static ExitPromptStyle? tryParse(String? value) {
    final name = value?.trim();
    for (final style in values) {
      if (style.wireName == name) return style;
    }
    return null;
  }
}

/// How the Exit button looks.
enum ExitButtonEmphasis {
  /// Readable, like any secondary button.
  standard('standard'),

  /// Muted grey, so the ad and Cancel lead. Still labeled and working.
  dimmed('dimmed');

  const ExitButtonEmphasis(this.wireName);

  /// The name in remote config and analytics.
  final String wireName;

  /// The emphasis named [value], or null.
  static ExitButtonEmphasis? tryParse(String? value) {
    final name = value?.trim();
    for (final emphasis in values) {
      if (emphasis.wireName == name) return emphasis;
    }
    return null;
  }
}

/// The ad a prompt shows.
final class ExitPromptAd {
  /// Creates an ad slot.
  const ExitPromptAd({required this.builder, required this.height});

  /// Builds the ad, with its own placeholder until it loads.
  final WidgetBuilder builder;

  /// The space kept for the ad, so nothing moves when it loads.
  final double height;
}

/// One of the app's features, on the features sheet.
final class ExitPromptFeature {
  /// Creates a feature.
  const ExitPromptFeature({
    required this.id,
    required this.title,
    required this.onSelected,
    this.subtitle,
    this.icon,
    this.actionLabel = 'Try Now',
  });

  /// Reported as the result's `targetId`.
  final String id;

  /// The feature's name.
  final String title;

  /// One line about it.
  final String? subtitle;

  /// Shown beside the title.
  final Widget? icon;

  /// The button.
  final String actionLabel;

  /// Runs with the guard's context after the prompt closes.
  final void Function(BuildContext context) onSelected;
}

/// The offer on the offer sheet.
final class ExitPromptOffer {
  /// Creates an offer.
  const ExitPromptOffer({
    required this.id,
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.message,
    this.artwork,
  });

  /// Reported as the result's `targetId`.
  final String id;

  /// The headline.
  final String title;

  /// One or two lines under it.
  final String? message;

  /// Above the headline.
  final WidgetBuilder? artwork;

  /// The button.
  final String actionLabel;

  /// Runs with the guard's context after the prompt closes.
  final void Function(BuildContext context) onAction;
}

/// Text in the prompts.
final class ExitPromptLabels {
  /// Creates labels.
  const ExitPromptLabels({
    this.title = 'Do you want to exit the app?',
    this.message = 'Are you sure you want to leave?',
    this.exit = 'Exit',
    this.cancel = 'Cancel',
    this.featuresTitle = 'Have you checked these features?',
    this.doubleTapHint = 'Press back again to exit',
  });

  /// The exit question.
  final String title;

  /// Under the question, where a style has room.
  final String message;

  /// The Exit button.
  final String exit;

  /// The Cancel button.
  final String cancel;

  /// Above the features carousel.
  final String featuresTitle;

  /// After the first Back, in the double-tap style.
  final String doubleTapHint;
}

/// Colors and sizes of the prompts.
final class ExitPromptTheme {
  /// Creates a theme.
  const ExitPromptTheme({
    this.accentColor,
    this.surfaceColor = const Color(0xFFFFFFFF),
    this.adBackgroundColor = const Color(0xFFF1F3F5),
    this.titleStyle,
    this.messageStyle,
    this.cornerRadius = 24,
    this.buttonHeight = 56,
    this.standardExitBackground = const Color(0xFFE8EAED),
    this.standardExitForeground = const Color(0xFF202124),
    this.dimmedExitBackground = const Color(0xFF9AA0A6),
    this.dimmedExitForeground = const Color(0xFFDADCE0),
    this.offerBackgroundColor = const Color(0xFF121212),
    this.offerTextColor = const Color(0xFFFFFFFF),
  });

  /// Cancel, feature and offer buttons, and icons. Null uses the theme's
  /// primary.
  final Color? accentColor;

  /// Sheet and dialog background.
  final Color surfaceColor;

  /// Behind the ad.
  final Color adBackgroundColor;

  /// The exit question. Null uses the theme's title, bold.
  final TextStyle? titleStyle;

  /// The message. Null uses the theme's body, grey.
  final TextStyle? messageStyle;

  /// Sheet top corners and dialog corners.
  final double cornerRadius;

  /// Full-width buttons.
  final double buttonHeight;

  /// A standard Exit button.
  final Color standardExitBackground;

  /// A standard Exit button's text.
  final Color standardExitForeground;

  /// A dimmed Exit button.
  final Color dimmedExitBackground;

  /// A dimmed Exit button's text.
  final Color dimmedExitForeground;

  /// The offer sheet.
  final Color offerBackgroundColor;

  /// Text on the offer sheet.
  final Color offerTextColor;
}

/// What the user chose.
enum ExitPromptAction {
  /// Close the app.
  exit,

  /// Stay: Cancel, or the prompt dismissed.
  stay,

  /// A feature on the features sheet.
  feature,

  /// The offer on the offer sheet.
  offer,
}

/// The outcome of a prompt.
final class ExitPromptResult {
  /// Creates a result.
  const ExitPromptResult({
    required this.style,
    required this.action,
    this.targetId,
  });

  /// The style that showed.
  final ExitPromptStyle style;

  /// What the user chose.
  final ExitPromptAction action;

  /// The feature or offer ID, for [ExitPromptAction.feature] and
  /// [ExitPromptAction.offer].
  final String? targetId;
}

/// Everything a prompt needs.
final class ExitPromptConfig {
  /// Creates a config.
  const ExitPromptConfig({
    this.style = ExitPromptStyle.featuresSheet,
    this.fallbackStyle = ExitPromptStyle.confirmDialog,
    this.exitButton = ExitButtonEmphasis.standard,
    this.ad,
    this.features = const <ExitPromptFeature>[],
    this.offer,
    this.labels = const ExitPromptLabels(),
    this.theme = const ExitPromptTheme(),
    this.doubleTapWindow = const Duration(seconds: 2),
  });

  /// The style asked for.
  final ExitPromptStyle style;

  /// Shown when [style] lacks what it needs.
  final ExitPromptStyle fallbackStyle;

  /// How the Exit button looks.
  final ExitButtonEmphasis exitButton;

  /// The ad, or null when this user gets none.
  final ExitPromptAd? ad;

  /// For the features sheet.
  final List<ExitPromptFeature> features;

  /// For the offer sheet.
  final ExitPromptOffer? offer;

  /// Text.
  final ExitPromptLabels labels;

  /// Colors and sizes.
  final ExitPromptTheme theme;

  /// How soon the second Back must come in the double-tap style.
  final Duration doubleTapWindow;

  /// The style that will show: [style], else [fallbackStyle], else a plain
  /// confirmation.
  ExitPromptStyle get resolvedStyle {
    if (canShow(style)) return style;
    if (canShow(fallbackStyle)) return fallbackStyle;
    return ExitPromptStyle.confirmDialog;
  }

  /// Whether [style] has what it needs here.
  bool canShow(ExitPromptStyle style) => switch (style) {
        ExitPromptStyle.adSheet || ExitPromptStyle.adDialog => ad != null,
        ExitPromptStyle.featuresSheet => features.isNotEmpty,
        ExitPromptStyle.offerSheet => offer != null,
        _ => true,
      };

  /// A copy with the given fields replaced.
  ExitPromptConfig copyWith({
    ExitPromptStyle? style,
    ExitPromptStyle? fallbackStyle,
    ExitButtonEmphasis? exitButton,
  }) {
    return ExitPromptConfig(
      style: style ?? this.style,
      fallbackStyle: fallbackStyle ?? this.fallbackStyle,
      exitButton: exitButton ?? this.exitButton,
      ad: ad,
      features: features,
      offer: offer,
      labels: labels,
      theme: theme,
      doubleTapWindow: doubleTapWindow,
    );
  }
}
