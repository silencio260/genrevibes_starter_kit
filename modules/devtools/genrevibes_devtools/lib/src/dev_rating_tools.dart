import 'package:flutter/widgets.dart';

/// The app's own half of rating, for the Rating page.
///
/// The kit decides whether to ask; the app owns the prompt, its good moments
/// and its counters. These hooks let the bench run that real flow instead of
/// a copy, so what passes here is what users get.
final class DevRatingTools {
  /// Creates the hooks. Each one left out hides its action.
  const DevRatingTools({
    this.triggers = const <String>[],
    this.askNow,
    this.previewPrompt,
    this.installSource,
  });

  /// Trigger counters the app records, such as `download`. They are shown
  /// with the history, and a full reset clears them so a milestone ask can be
  /// replayed.
  final List<String> triggers;

  /// Runs the app's real ask now, past the timing rules but never past an
  /// opt-out. It records exactly what a real ask records. [context] belongs to
  /// the bench page, so a prompt can appear over it. The returned value is
  /// shown as the result, for example which channel ran.
  final Future<Object?> Function(BuildContext context)? askNow;

  /// Shows the app's prompt without recording anything, and returns what was
  /// chosen.
  final Future<Object?> Function(BuildContext context)? previewPrompt;

  /// Which store installed this build, such as `com.android.vending`. `null`
  /// means it was side-loaded. Store review sheets only appear for store
  /// installs, so the page warns when this is anything else.
  final Future<String?> Function()? installSource;
}
