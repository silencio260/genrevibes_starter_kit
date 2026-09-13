import 'package:flutter/painting.dart';
import 'package:genrevibes_feedback/genrevibes_feedback.dart';

/// Picks a screenshot to attach, or returns null when the user cancels.
///
/// Supplied by the app, so the kit takes no image picker dependency.
typedef FeedbackScreenshotPicker = Future<FeedbackAttachment?> Function();

/// Text on the feedback page.
///
/// The defaults are for product feedback; [contact] is the support request.
final class FeedbackPageLabels {
  /// Creates labels.
  const FeedbackPageLabels({
    this.title = 'Send feedback',
    this.subtitle = 'Tell us what works and what doesn\'t.',
    this.emailLabel = 'Email',
    this.optional = 'optional',
    this.emailHint = 'name@example.com',
    this.messageLabel = 'Your feedback',
    this.messageHint = 'What would make the app better for you?',
    this.screenshotLabel = 'Screenshot',
    this.addScreenshot = 'Add a screenshot',
    this.removeScreenshot = 'Remove screenshot',
    this.submit = 'Send feedback',
    this.successTitle = 'Thanks for your feedback',
    this.successMessage = 'We read every message.',
    this.done = 'Done',
    this.emailRequired = 'Enter your email so we can reply.',
    this.emailInvalid = 'Enter a valid email address.',
    this.messageRequired = 'Write a message first.',
    this.sendFailed =
        'Your message didn\'t send. Check your connection and try again.',
    this.screenshotFailed = 'That screenshot couldn\'t be attached.',
    this.attachmentTooLarge = 'That attachment is too large.',
    this.sendUnconfirmed =
        'We could not confirm delivery. Your message may have been sent. Retrying could send it twice.',
  });

  /// Wording for a support request.
  static const FeedbackPageLabels contact = FeedbackPageLabels(
    title: 'Contact us',
    subtitle: 'Ask us anything. We\'ll reply by email.',
    messageLabel: 'Your message',
    messageHint: 'How can we help?',
    submit: 'Send message',
    successTitle: 'Message sent',
    successMessage: 'We\'ll get back to you by email soon.',
  );

  /// The default wording for [kind].
  static FeedbackPageLabels forKind(FeedbackKind kind) => switch (kind) {
        FeedbackKind.feedback => const FeedbackPageLabels(),
        FeedbackKind.contact => contact,
      };

  /// The page title.
  final String title;

  /// One line above the form.
  final String subtitle;

  /// Above the email field.
  final String emailLabel;

  /// Shown after a label whose field is optional.
  final String optional;

  /// Inside the empty email field.
  final String emailHint;

  /// Above the message field.
  final String messageLabel;

  /// Inside the empty message field.
  final String messageHint;

  /// Above the screenshots.
  final String screenshotLabel;

  /// The add screenshot button.
  final String addScreenshot;

  /// The remove button on a screenshot, for screen readers.
  final String removeScreenshot;

  /// The send button.
  final String submit;

  /// Heading after sending.
  final String successTitle;

  /// Message after sending.
  final String successMessage;

  /// Leaves the page after sending.
  final String done;

  /// When a required email is empty.
  final String emailRequired;

  /// When the email is not an address.
  final String emailInvalid;

  /// When the message is empty.
  final String messageRequired;

  /// When the provider reports a failure.
  final String sendFailed;

  /// When picking a screenshot throws.
  final String screenshotFailed;
  final String attachmentTooLarge;
  final String sendUnconfirmed;
}

/// Colors and shape of the feedback page.
///
/// Null values come from the app's `ThemeData`. Pass the colors of the app's
/// own settings pages, so the form looks like the screen it was opened from.
final class FeedbackPageTheme {
  /// Creates a theme.
  const FeedbackPageTheme({
    this.appBarColor,
    this.appBarForegroundColor,
    this.appBarTitleStyle,
    this.centerTitle,
    this.backgroundColor,
    this.accentColor,
    this.fieldColor = const Color(0xFFEEEEEE),
    this.textColor = const Color(0xFF424242),
    this.secondaryTextColor = const Color(0xFF757575),
    this.cornerRadius = 12,
  });

  /// The app bar.
  final Color? appBarColor;

  /// The title and back arrow.
  final Color? appBarForegroundColor;

  /// The title. Without a color of its own it takes [appBarForegroundColor].
  final TextStyle? appBarTitleStyle;

  /// Whether the title is centered.
  final bool? centerTitle;

  /// Behind the form.
  final Color? backgroundColor;

  /// Buttons, focus and the success mark. Null uses the theme's primary.
  final Color? accentColor;

  /// Text field fill.
  final Color fieldColor;

  /// Labels and headings.
  final Color textColor;

  /// The line above the form, and hints.
  final Color secondaryTextColor;

  /// Fields and buttons.
  final double cornerRadius;
}
