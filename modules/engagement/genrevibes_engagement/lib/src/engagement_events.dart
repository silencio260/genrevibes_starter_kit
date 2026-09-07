/// Canonical analytics event names emitted by this package.
///
/// Applications rename these through `AnalyticsEventNames` on the pipeline,
/// never by editing emitters.
abstract final class EngagementEvents {
  /// Every app open.
  static const appOpened = 'retention_app_opened';

  /// Every session start, including foreground resumes.
  static const sessionStarted = 'retention_session_started';

  /// Returned on the given day after install.
  static const day1Returned = 'retention_day_1_returned';

  /// Returned three days after install.
  static const day3Returned = 'retention_day_3_returned';

  /// Returned a week after install.
  static const day7Returned = 'retention_day_7_returned';

  /// Returned a month after install.
  static const day30Returned = 'retention_day_30_returned';

  /// Profile evaluated; carries the full property map.
  static const segmentUpdate = 'user_segment_update';

  /// Profile evaluated as loyal.
  static const userIsLoyal = 'user_is_loyal';

  /// Profile evaluated as at risk.
  static const userAtRisk = 'user_at_risk';

  /// Profile evaluated as churned.
  static const userChurned = 'user_churned';

  /// Profile evaluated as a power user.
  static const userIsPowerUser = 'user_is_power_user';
}
