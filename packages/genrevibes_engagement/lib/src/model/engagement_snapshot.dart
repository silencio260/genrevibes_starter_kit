/// Immutable, fully computed view of one user's retention history.
///
/// Everything a segment or a prompt decision needs is derived here once, from
/// raw persisted state and an injected "now", so policy code stays pure and
/// tests never depend on the wall clock.
final class EngagementSnapshot {
  /// Computes a snapshot from persisted state.
  ///
  /// [activeDates] must be date-only values; [sessionTimestamps] are instants.
  factory EngagementSnapshot.compute({
    required DateTime now,
    required DateTime? installedAt,
    required DateTime? lastOpenedAt,
    required int totalOpens,
    required List<DateTime> sessionTimestamps,
    required List<DateTime> activeDates,
  }) {
    final today = _dateOnly(now);
    final tomorrow = today.add(const Duration(days: 1));
    final sessionsToday = sessionTimestamps
        .where((t) => !t.isBefore(today) && t.isBefore(tomorrow))
        .length;
    final dates = List<DateTime>.unmodifiable(activeDates.map(_dateOnly));
    return EngagementSnapshot._(
      observedAt: now,
      installedAt: installedAt,
      lastOpenedAt: lastOpenedAt,
      totalOpens: totalOpens,
      sessionsToday: sessionsToday,
      activeDates: dates,
      daysSinceInstall:
          installedAt == null ? 0 : now.difference(installedAt).inDays,
      daysSinceLastOpen:
          lastOpenedAt == null ? 0 : now.difference(lastOpenedAt).inDays,
    );
  }

  const EngagementSnapshot._({
    required this.observedAt,
    required this.installedAt,
    required this.lastOpenedAt,
    required this.totalOpens,
    required this.sessionsToday,
    required this.activeDates,
    required this.daysSinceInstall,
    required this.daysSinceLastOpen,
  });

  /// When this snapshot was computed.
  final DateTime observedAt;

  /// First recorded open, or `null` before the first open.
  final DateTime? installedAt;

  /// Most recent recorded open.
  final DateTime? lastOpenedAt;

  /// Lifetime app opens.
  final int totalOpens;

  /// Sessions started today.
  final int sessionsToday;

  /// Distinct calendar days with at least one open.
  final List<DateTime> activeDates;

  /// Whole days since install.
  final int daysSinceInstall;

  /// Whole days since the last open.
  final int daysSinceLastOpen;

  /// Number of distinct active days.
  int get activeDays => activeDates.length;

  /// Whether the user opened the app on the given day after install (1..7).
  bool returnedOnDay(int day) {
    final installed = installedAt;
    if (installed == null || day < 1 || day > 7) return false;
    final target = _dateOnly(installed).add(Duration(days: day));
    return activeDates.any((d) => d == target);
  }

  /// Whether the user opened the app during the given week after install
  /// (1..4).
  bool returnedOnWeek(int week) {
    if (week < 1 || week > 4) return false;
    final installed = installedAt;
    if (installed == null) return false;
    final start = _dateOnly(installed).add(Duration(days: (week - 1) * 7 + 1));
    final end = _dateOnly(installed).add(Duration(days: week * 7 + 1));
    return activeDates.any((d) => !d.isBefore(start) && d.isBefore(end));
  }

  /// Whether the user opened the app during the given 30-day month after
  /// install (1..12).
  bool returnedOnMonth(int month) {
    if (month < 1 || month > 12) return false;
    final installed = installedAt;
    if (installed == null) return false;
    final start =
        _dateOnly(installed).add(Duration(days: (month - 1) * 30 + 1));
    final end = _dateOnly(installed).add(Duration(days: month * 30 + 1));
    return activeDates.any((d) => !d.isBefore(start) && d.isBefore(end));
  }

  /// Share of days 1..7 after install with an open, as a percentage.
  double get d7RetentionRate {
    if (installedAt == null) return 0;
    var active = 0;
    for (var day = 1; day <= 7; day++) {
      if (returnedOnDay(day)) active++;
    }
    return active / 7 * 100;
  }

  /// Share of weeks 1..4 after install with an open, as a percentage.
  double get weeklyRetentionRate {
    if (installedAt == null) return 0;
    var active = 0;
    for (var week = 1; week <= 4; week++) {
      if (returnedOnWeek(week)) active++;
    }
    return active / 4 * 100;
  }

  /// Share of months 1..12 after install with an open, as a percentage.
  double get monthlyRetentionRate {
    if (installedAt == null) return 0;
    var active = 0;
    for (var month = 1; month <= 12; month++) {
      if (returnedOnMonth(month)) active++;
    }
    return active / 12 * 100;
  }

  /// Non-sensitive metrics suitable as analytics event properties.
  Map<String, Object?> toProperties() => <String, Object?>{
        'days_since_install': daysSinceInstall,
        'days_since_last_open': daysSinceLastOpen,
        'total_opens': totalOpens,
        'sessions_today': sessionsToday,
        'active_days_count': activeDays,
        'd7_retention_rate': d7RetentionRate,
        'weekly_retention_rate': weeklyRetentionRate,
        'monthly_retention_rate': monthlyRetentionRate,
      };

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
