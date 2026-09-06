import 'model/retention_milestone.dart';

/// Storage keys used by [RetentionTracker].
///
/// Dates are ISO-8601 strings and the two histories are string lists, matching
/// the format hand-rolled retention trackers in the portfolio already write, so
/// the legacy mappings adopt existing installs without a conversion step.
abstract final class EngagementKeys {
  /// First open, ISO-8601.
  static const installedAt = 'genrevibes.engagement.installed_at.v1';

  /// Most recent open, ISO-8601.
  static const lastOpenedAt = 'genrevibes.engagement.last_opened_at.v1';

  /// Lifetime opens.
  static const totalOpens = 'genrevibes.engagement.total_opens.v1';

  /// Session instants, ISO-8601 list.
  static const sessionTimestamps =
      'genrevibes.engagement.session_timestamps.v1';

  /// Distinct active dates, ISO-8601 list.
  static const dailyOpenDates = 'genrevibes.engagement.daily_open_dates.v1';

  /// Whether the given milestone was already reported.
  static String milestone(RetentionMilestone milestone) =>
      'genrevibes.engagement.milestone.day${milestone.day}.v1';

  /// Legacy key names to adopt, mapped from their current equivalents.
  static const legacyKeys = <String, String>{
    installedAt: 'first_install_date',
    lastOpenedAt: 'last_open_date',
    totalOpens: 'total_app_opens',
    sessionTimestamps: 'session_timestamps',
    dailyOpenDates: 'daily_open_dates',
  };
}
