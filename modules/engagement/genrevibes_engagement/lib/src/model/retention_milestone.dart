/// Days after install on which a return is reported as a milestone.
enum RetentionMilestone {
  /// Returned the day after install.
  day1(1),

  /// Returned two days after install.
  day2(2),

  /// Returned three days after install.
  day3(3),

  /// Returned four days after install.
  day4(4),

  /// Returned five days after install.
  day5(5),

  /// Returned six days after install.
  day6(6),

  /// Returned a week after install.
  day7(7),

  /// Returned a month after install.
  day30(30);

  const RetentionMilestone(this.day);

  /// Days since install this milestone represents.
  final int day;

  /// The milestone for [daysSinceInstall], or `null` when it is not one.
  static RetentionMilestone? forDay(int daysSinceInstall) {
    for (final milestone in values) {
      if (milestone.day == daysSinceInstall) return milestone;
    }
    return null;
  }
}
