import 'package:genrevibes_core/genrevibes_core.dart';

import 'model/push_event.dart';
import 'model/push_subscription_state.dart';

/// Contract implemented by OneSignal and future remote-push adapters.
abstract interface class PushNotificationProvider implements StarterModule {
  /// Stable provider identifier, such as `onesignal`.
  String get providerId;

  /// Permission, subscription, receipt, and open events.
  Stream<PushEvent> get events;

  /// Reads all state required to diagnose remote push delivery.
  Future<KitResult<PushSubscriptionState>> getSubscriptionState();

  /// Requests operating-system permission at an app-chosen moment.
  Future<KitResult<PushSubscriptionState>> requestPermission({
    bool fallbackToSettings = false,
  });

  /// Enables provider delivery, requesting OS permission if necessary.
  Future<KitResult<PushSubscriptionState>> optIn();

  /// Disables provider delivery without changing OS permission.
  Future<KitResult<PushSubscriptionState>> optOut();

  /// Associates an application user with the provider.
  Future<KitResult<void>> identify(String externalUserId);

  /// Returns to an anonymous/device-scoped provider user.
  Future<KitResult<void>> resetIdentity();

  /// Adds or replaces targeting tags.
  Future<KitResult<void>> setTags(Map<String, String> tags);

  /// Removes targeting tags.
  Future<KitResult<void>> removeTags(Iterable<String> keys);
}
