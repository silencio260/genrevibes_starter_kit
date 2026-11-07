/// Completion of an individual tutorial, separate from app onboarding.
enum TutorialOutcome { inProgress, completed, skipped }

/// One atomic snapshot. Stable step IDs survive step reordering.
final class TutorialProgress {
  const TutorialProgress(
      {required this.stepId, this.outcome = TutorialOutcome.inProgress});

  final String stepId;
  final TutorialOutcome outcome;
  bool get isCompleted => outcome != TutorialOutcome.inProgress;

  Map<String, Object> toJson() =>
      {'schema': 1, 'stepId': stepId, 'outcome': outcome.name};

  factory TutorialProgress.fromJson(Map<String, dynamic> json) {
    if (json['schema'] != 1 || json['stepId'] is! String) {
      throw const FormatException('Unsupported tutorial progress');
    }
    final outcome = TutorialOutcome.values
        .where((value) => value.name == json['outcome'])
        .firstOrNull;
    if (outcome == null) {
      throw const FormatException('Unknown tutorial outcome');
    }
    return TutorialProgress(stepId: json['stepId'] as String, outcome: outcome);
  }
}
