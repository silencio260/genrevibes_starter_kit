import 'package:genrevibes_core/genrevibes_core.dart';

import 'model/local_notification.dart';

/// Contract implemented by an optional platform local-notifications adapter.
abstract interface class LocalNotificationScheduler implements StarterModule {
  /// Notification taps and action selections.
  Stream<LocalNotificationInteraction> get interactions;

  /// Requests presentation permission at an app-chosen moment.
  Future<KitResult<bool>> requestPermission();

  /// Shows [content] immediately, replacing the same [id].
  Future<KitResult<void>> show(int id, LocalNotificationContent content);

  /// Schedules or replaces [request].
  Future<KitResult<void>> schedule(LocalNotificationRequest request);

  /// Returns notifications still pending with the operating system.
  Future<KitResult<List<PendingLocalNotification>>> pending();

  /// Cancels one local notification.
  Future<KitResult<void>> cancel(int id);

  /// Cancels every local notification owned by the host application.
  Future<KitResult<void>> cancelAll();
}
