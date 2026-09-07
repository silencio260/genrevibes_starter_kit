import 'engagement_snapshot.dart';
import 'targeting_decisions.dart';
import 'user_segment.dart';

/// Segment, level, score and decisions for one snapshot.
final class UserProfile {
  /// Creates a profile.
  const UserProfile({
    required this.snapshot,
    required this.segment,
    required this.level,
    required this.score,
    required this.isFirstTime,
    required this.isNew,
    required this.isReturning,
    required this.isLoyal,
    required this.isPowerUser,
    required this.isAtRisk,
    required this.isChurned,
    required this.isFrequentToday,
    required this.decisions,
  });

  /// The history this profile was derived from.
  final EngagementSnapshot snapshot;

  /// Highest-priority matching segment.
  final UserSegment segment;

  /// Engagement level.
  final EngagementLevel level;

  /// Engagement score, 0..100.
  final int score;

  /// First ever session.
  final bool isFirstTime;

  /// Installed recently.
  final bool isNew;

  /// Has opened the app more than once.
  final bool isReturning;

  /// Meets the loyal threshold.
  final bool isLoyal;

  /// Meets the power-user threshold.
  final bool isPowerUser;

  /// Absent long enough to be at risk.
  final bool isAtRisk;

  /// Absent long enough to be churned.
  final bool isChurned;

  /// Several sessions today.
  final bool isFrequentToday;

  /// Prompt recommendations.
  final TargetingDecisions decisions;

  /// Analytics properties, matching the portfolio's `user_segment_update`
  /// payload.
  Map<String, Object?> toProperties() => <String, Object?>{
        'segment': segment.wireName,
        'engagement_level': level.wireName,
        'engagement_score': score,
        'is_first_time': isFirstTime,
        'is_new': isNew,
        'is_returning': isReturning,
        'is_loyal': isLoyal,
        'is_power_user': isPowerUser,
        'is_at_risk': isAtRisk,
        'is_churned': isChurned,
        'is_frequent': isFrequentToday,
        ...snapshot.toProperties(),
      };
}
