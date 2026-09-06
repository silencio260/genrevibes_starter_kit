/// Thresholds that decide when a rating prompt may be shown.
///
/// Defaults match the behavior proven in production: a user must have had the
/// app installed a few days, opened it several times, and not been prompted
/// recently.
final class RatingCriteria {
  /// Creates rating criteria.
  const RatingCriteria({
    this.minimumAppOpens = 5,
    this.minimumInstallAge = const Duration(days: 3),
    this.minimumIntervalBetweenPrompts = const Duration(days: 7),
    this.snooze = const Duration(days: 2),
  });

  /// Times the app must have been opened before prompting.
  final int minimumAppOpens;

  /// How long the app must have been installed before prompting.
  final Duration minimumInstallAge;

  /// Minimum gap between two prompts.
  final Duration minimumIntervalBetweenPrompts;

  /// How long "maybe later" defers the next prompt.
  ///
  /// This is deliberately shorter than [minimumIntervalBetweenPrompts]. A user
  /// who deferred is more receptive than one who has never been asked, so the
  /// coordinator re-qualifies them sooner rather than waiting a full interval.
  final Duration snooze;
}
