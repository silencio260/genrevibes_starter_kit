/// Accuracy/battery policy for Android scheduled notifications.
enum GenreVibesAndroidScheduleMode {
  /// Allows Android to batch delivery while still running during idle.
  inexactAllowWhileIdle,

  /// Exact delivery while idle; requires additional Android permission/setup.
  exactAllowWhileIdle,
}

/// Platform initialization and timezone policy.
final class GenreVibesLocalNotificationsConfiguration {
  /// Creates local notification configuration.
  const GenreVibesLocalNotificationsConfiguration({
    required this.androidDefaultIcon,
    required this.timeZoneName,
    this.androidScheduleMode =
        GenreVibesAndroidScheduleMode.inexactAllowWhileIdle,
  });

  /// Android drawable/mipmap resource, for example `@mipmap/ic_launcher`.
  final String androidDefaultIcon;

  /// IANA device timezone, for example `Africa/Lagos`.
  ///
  /// Resolve this in the host app from the device. It is explicit because using
  /// UTC silently would shift daily notifications after travel or DST changes.
  final String timeZoneName;

  /// Android alarm accuracy policy.
  final GenreVibesAndroidScheduleMode androidScheduleMode;
}
