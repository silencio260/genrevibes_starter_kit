/// Coarse lifecycle segment, highest priority first.
enum UserSegment {
  /// Twenty or more active days, or fifty or more opens.
  powerUser('power_user'),

  /// Seven or more active days.
  loyal('loyal'),

  /// Absent for a week or more.
  churned('churned'),

  /// Absent for three to six days.
  atRisk('at_risk'),

  /// Has opened the app more than once.
  returning('returning'),

  /// In their first ever session.
  firstTime('first_time'),

  /// Everyone else, typically an early install that has not yet returned.
  newUser('new');

  const UserSegment(this.wireName);

  /// Stable analytics value.
  final String wireName;
}

/// How engaged a user is, used to gate feature and upsell prompts.
enum EngagementLevel {
  /// First ever session.
  firstTime('first_time'),

  /// Fewer than three active days and fewer than five opens.
  low('low'),

  /// Three to six active days, or five to fourteen opens.
  medium('medium'),

  /// Seven or more active days, or fifteen or more opens.
  high('high'),

  /// Twenty or more active days, or fifty or more opens.
  powerUser('power_user');

  const EngagementLevel(this.wireName);

  /// Stable analytics value.
  final String wireName;
}
