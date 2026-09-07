import 'model/engagement_snapshot.dart';
import 'model/targeting_decisions.dart';
import 'model/user_profile.dart';
import 'model/user_segment.dart';
import 'model/user_targeting_thresholds.dart';

/// Pure segmentation and prompt-targeting rules over an [EngagementSnapshot].
///
/// Stateless and clock-free: every input is on the snapshot. That is what makes
/// the rules unit-testable and identical across every app in the portfolio.
final class UserTargetingPolicy {
  /// Creates a policy.
  const UserTargetingPolicy({
    this.thresholds = const UserTargetingThresholds(),
  });

  /// Numeric boundaries.
  final UserTargetingThresholds thresholds;

  /// Derives the full profile for [s].
  UserProfile profile(EngagementSnapshot s) {
    final t = thresholds;
    final firstTime = s.totalOpens == 1;
    final isNew = s.daysSinceInstall < t.newUserMaxDays;
    final returning = s.totalOpens > 1;
    final loyal = s.activeDays >= t.loyalActiveDays;
    final power =
        s.activeDays >= t.powerActiveDays || s.totalOpens >= t.powerOpens;
    final atRisk = s.daysSinceLastOpen >= t.atRiskMinDays &&
        s.daysSinceLastOpen < t.churnedDays;
    final churned = s.daysSinceLastOpen >= t.churnedDays;
    final frequent = s.sessionsToday >= t.frequentSessionsToday;

    final level = _level(s, firstTime: firstTime, power: power);
    final wasChurnedAndBack =
        s.daysSinceLastOpen == 0 && s.daysSinceInstall >= t.churnedDays;

    return UserProfile(
      snapshot: s,
      segment: _segment(
        power: power,
        loyal: loyal,
        churned: churned,
        atRisk: atRisk,
        returning: returning,
        firstTime: firstTime,
      ),
      level: level,
      score: _score(s),
      isFirstTime: firstTime,
      isNew: isNew,
      isReturning: returning,
      isLoyal: loyal,
      isPowerUser: power,
      isAtRisk: atRisk,
      isChurned: churned,
      isFrequentToday: frequent,
      decisions: TargetingDecisions(
        welcomeOffer: firstTime,
        onboardingTips: s.daysSinceInstall >= 0 && s.daysSinceInstall <= 3,
        retentionOffer: s.daysSinceInstall == 3 && s.activeDays <= 2,
        loyaltyReward: s.daysSinceInstall == 7 &&
            s.d7RetentionRate >= t.loyaltyRewardD7Rate,
        reEngagementOffer: atRisk,
        winbackOffer: wasChurnedAndBack,
        advancedFeatures: power || level == EngagementLevel.high,
        premiumUpsell:
            level == EngagementLevel.high || level == EngagementLevel.powerUser,
        ratingPrompt: s.daysSinceInstall >= 3 &&
            s.daysSinceInstall <= 7 &&
            s.activeDays >= 3,
        notificationRequest: s.daysSinceInstall == 2 && s.totalOpens >= 3,
        helpTutorial: level == EngagementLevel.low,
      ),
    );
  }

  /// Segment precedence: power > loyal > churned > at risk > returning >
  /// first time > new.
  UserSegment _segment({
    required bool power,
    required bool loyal,
    required bool churned,
    required bool atRisk,
    required bool returning,
    required bool firstTime,
  }) {
    if (power) return UserSegment.powerUser;
    if (loyal) return UserSegment.loyal;
    if (churned) return UserSegment.churned;
    if (atRisk) return UserSegment.atRisk;
    if (returning) return UserSegment.returning;
    if (firstTime) return UserSegment.firstTime;
    return UserSegment.newUser;
  }

  EngagementLevel _level(
    EngagementSnapshot s, {
    required bool firstTime,
    required bool power,
  }) {
    final t = thresholds;
    if (firstTime) return EngagementLevel.firstTime;
    if (power) return EngagementLevel.powerUser;
    if (s.activeDays >= t.highActiveDays || s.totalOpens >= t.highOpens) {
      return EngagementLevel.high;
    }
    if (s.activeDays >= t.mediumActiveDays || s.totalOpens >= t.mediumOpens) {
      return EngagementLevel.medium;
    }
    return EngagementLevel.low;
  }

  /// Weighted 0..100 score: active days (max 40), opens (max 30), D7 rate
  /// (max 20), recency bonus (10 today, 5 yesterday).
  int _score(EngagementSnapshot s) {
    var score = 0;
    score += (s.activeDays * 2).clamp(0, 40);
    score += (s.totalOpens ~/ 2).clamp(0, 30);
    score += (s.d7RetentionRate / 5).toInt().clamp(0, 20);
    if (s.daysSinceLastOpen == 0) {
      score += 10;
    } else if (s.daysSinceLastOpen == 1) {
      score += 5;
    }
    return score.clamp(0, 100);
  }
}
