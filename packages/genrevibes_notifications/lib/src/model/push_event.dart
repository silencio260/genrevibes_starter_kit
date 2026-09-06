import 'push_subscription_state.dart';

/// A push payload normalized across providers.
final class PushMessage {
  /// Creates a push message.
  const PushMessage({
    required this.messageId,
    this.title,
    this.body,
    this.actionId,
    this.additionalData = const <String, Object?>{},
  });

  /// Provider message identifier.
  final String messageId;

  /// Notification title.
  final String? title;

  /// Notification body.
  final String? body;

  /// Action selected by the user, when present.
  final String? actionId;

  /// Application-defined push data.
  final Map<String, Object?> additionalData;
}

/// Events emitted by a [PushNotificationProvider].
sealed class PushEvent {
  const PushEvent();
}

/// Permission or provider subscription state changed.
final class PushStateChanged extends PushEvent {
  /// Creates a state-change event.
  const PushStateChanged({required this.reason, required this.state});

  /// Stable reason such as `permission`, `subscription`, or `refresh`.
  final String reason;

  /// Complete state after the change.
  final PushSubscriptionState state;
}

/// A notification arrived while the app was in the foreground.
final class PushMessageReceived extends PushEvent {
  /// Creates a foreground delivery event.
  const PushMessageReceived(this.message);

  /// Normalized message.
  final PushMessage message;
}

/// The user opened or acted on a notification.
final class PushMessageOpened extends PushEvent {
  /// Creates a message-open event.
  const PushMessageOpened(this.message);

  /// Normalized message.
  final PushMessage message;
}
