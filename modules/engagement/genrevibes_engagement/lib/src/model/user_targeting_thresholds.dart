/// Numeric boundaries behind segments, levels and prompt decisions.
///
/// Defaults are the values proven in production. Apps override only what
/// their own analytics justify.
final class UserTargetingThresholds {
  /// Creates thresholds.
  const UserTargetingThresholds({
    this.newUserMaxDays = 7,
    this.loyalActiveDays = 7,
    this.powerActiveDays = 20,
    this.powerOpens = 50,
    this.highActiveDays = 7,
    this.highOpens = 15,
    this.mediumActiveDays = 3,
    this.mediumOpens = 5,
    this.atRiskMinDays = 3,
    this.churnedDays = 7,
    this.frequentSessionsToday = 3,
    this.loyaltyRewardD7Rate = 50,
  });

  /// Below this many days since install, a user is "new".
  final int newUserMaxDays;

  /// Active days required to be "loyal".
  final int loyalActiveDays;

  /// Active days required to be a "power user".
  final int powerActiveDays;

  /// Opens required to be a "power user".
  final int powerOpens;

  /// Active days for the "high" engagement level.
  final int highActiveDays;

  /// Opens for the "high" engagement level.
  final int highOpens;

  /// Active days for the "medium" engagement level.
  final int mediumActiveDays;

  /// Opens for the "medium" engagement level.
  final int mediumOpens;

  /// Days absent at which a user becomes "at risk".
  final int atRiskMinDays;

  /// Days absent at which a user is "churned".
  final int churnedDays;

  /// Sessions today at which a user is "frequent".
  final int frequentSessionsToday;

  /// Minimum D7 rate for the loyalty reward.
  final double loyaltyRewardD7Rate;
}
