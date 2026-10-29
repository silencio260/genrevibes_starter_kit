import 'rating_criteria.dart';
import 'rating_decision.dart';

/// Everything the coordinator has stored, read at one moment.
///
/// For diagnostics benches and support. Taking a snapshot never counts as an
/// evaluation, so it changes no state and reports nothing to the observer.
final class RatingSnapshot {
  /// Creates a snapshot.
  const RatingSnapshot({
    required this.now,
    required this.criteria,
    required this.decision,
    required this.installedAt,
    required this.appOpens,
    required this.lastPromptedAt,
    required this.optedOut,
    required this.triggers,
  });

  /// The coordinator's clock when this was taken. A shifted test clock shows
  /// here, not the device time.
  final DateTime now;

  /// The thresholds in force.
  final RatingCriteria criteria;

  /// What `evaluate()` would answer right now.
  final RatingDecision decision;

  /// First launch, or `null` before the first initialization.
  final DateTime? installedAt;

  /// Launches counted so far.
  final int appOpens;

  /// The last prompt, or `null` if none was ever shown.
  ///
  /// "Maybe later" back-dates this, so it can read earlier than the prompt
  /// actually appeared.
  final DateTime? lastPromptedAt;

  /// Whether the user asked never to be prompted again, or already answered.
  final bool optedOut;

  /// Named trigger counters, for the names the caller asked about.
  final Map<String, int> triggers;

  /// App opens still missing before the next prompt.
  int get appOpensMissing => appOpens >= criteria.minimumAppOpens
      ? 0
      : criteria.minimumAppOpens - appOpens;

  /// When the time-based rules next allow a prompt.
  ///
  /// The later of "installed long enough" and "long enough since the last
  /// prompt". `null` when the user opted out or no install date is stored.
  /// This ignores [appOpensMissing], which no amount of waiting satisfies.
  DateTime? get eligibleFrom {
    final installed = installedAt;
    if (optedOut || installed == null) return null;
    var from = installed.add(criteria.minimumInstallAge);
    final prompted = lastPromptedAt;
    if (prompted != null) {
      final afterInterval =
          prompted.add(criteria.minimumIntervalBetweenPrompts);
      if (afterInterval.isAfter(from)) from = afterInterval;
    }
    return from;
  }
}
