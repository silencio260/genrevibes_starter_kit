/// Importance of a local notification channel/presentation.
enum LocalNotificationImportance { low, normal, high }

/// Portable local notification content.
final class LocalNotificationContent {
  /// Creates local notification content.
  const LocalNotificationContent({
    required this.title,
    required this.body,
    this.payload,
    this.channelId = 'general',
    this.channelName = 'General notifications',
    this.channelDescription,
    this.importance = LocalNotificationImportance.normal,
  });

  /// Visible title.
  final String title;

  /// Visible body.
  final String body;

  /// Opaque application navigation/action payload.
  final String? payload;

  /// Stable Android channel identifier.
  final String channelId;

  /// Human-readable Android channel name.
  final String channelName;

  /// Optional Android channel description.
  final String? channelDescription;

  /// Portable importance hint.
  final LocalNotificationImportance importance;
}

/// Timing policy for a local notification.
sealed class LocalNotificationSchedule {
  const LocalNotificationSchedule();
}

/// Shows once at an absolute local time.
final class LocalNotificationOnce extends LocalNotificationSchedule {
  /// Creates a one-shot schedule.
  const LocalNotificationOnce(this.at);

  /// Local wall-clock delivery time.
  final DateTime at;
}

/// Repeats after a fixed duration.
final class LocalNotificationInterval extends LocalNotificationSchedule {
  /// Creates an interval schedule.
  LocalNotificationInterval(this.every) {
    if (every <= Duration.zero) {
      throw ArgumentError.value(every, 'every', 'Interval must be positive.');
    }
  }

  /// Delay between deliveries.
  final Duration every;
}

/// Repeats once per day at a local wall-clock time.
final class LocalNotificationDaily extends LocalNotificationSchedule {
  /// Creates a daily schedule.
  const LocalNotificationDaily({required this.hour, required this.minute})
      : assert(hour >= 0 && hour <= 23, 'Hour must be between 0 and 23.'),
        assert(minute >= 0 && minute <= 59, 'Minute must be between 0 and 59.');

  /// Local hour from 0 through 23.
  final int hour;

  /// Local minute from 0 through 59.
  final int minute;
}

/// A stable local notification and its timing policy.
final class LocalNotificationRequest {
  /// Creates a local notification request.
  const LocalNotificationRequest({
    required this.id,
    required this.content,
    required this.schedule,
  });

  /// Stable numeric identifier used for replacement and cancellation.
  final int id;

  /// Notification content.
  final LocalNotificationContent content;

  /// Delivery timing.
  final LocalNotificationSchedule schedule;
}

/// Minimal pending notification information used during reconciliation.
final class PendingLocalNotification {
  /// Creates pending notification information.
  const PendingLocalNotification({required this.id});

  /// Scheduled notification identifier.
  final int id;
}

/// User interaction with a local notification.
final class LocalNotificationInteraction {
  /// Creates a local notification interaction.
  const LocalNotificationInteraction({
    required this.notificationId,
    this.actionId,
    this.payload,
  });

  /// Notification identifier, when reported by the platform.
  final int? notificationId;

  /// Selected action identifier.
  final String? actionId;

  /// Opaque application payload supplied when the notification was created.
  final String? payload;
}
