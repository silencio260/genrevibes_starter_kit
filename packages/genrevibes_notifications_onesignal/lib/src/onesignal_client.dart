import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Push permission values exposed by the injectable OneSignal bridge.
enum OneSignalClientPermission {
  unknown,
  notDetermined,
  denied,
  authorized,
  provisional,
  ephemeral,
}

/// Provider state exposed by the injectable OneSignal bridge.
final class OneSignalClientState {
  /// Creates bridge state.
  const OneSignalClientState({
    required this.permission,
    required this.canRequestPermission,
    required this.optedIn,
    this.subscriptionId,
    this.pushToken,
    this.externalUserId,
  });

  final OneSignalClientPermission permission;
  final bool canRequestPermission;
  final bool? optedIn;
  final String? subscriptionId;
  final String? pushToken;
  final String? externalUserId;
}

/// Notification payload exposed by the injectable OneSignal bridge.
final class OneSignalClientMessage {
  /// Creates a bridge message.
  const OneSignalClientMessage({
    required this.id,
    this.title,
    this.body,
    this.actionId,
    this.additionalData = const <String, Object?>{},
  });

  final String id;
  final String? title;
  final String? body;
  final String? actionId;
  final Map<String, Object?> additionalData;
}

typedef OneSignalStateListener = void Function();
typedef OneSignalMessageListener = void Function(
    OneSignalClientMessage message);

/// Injectable seam around the static OneSignal Flutter SDK.
abstract interface class OneSignalClient {
  Future<void> configurePrivacy({
    required bool consentRequired,
    required bool? consentGranted,
  });
  Future<void> setVerboseLogging(bool enabled);
  void initialize(String appId);
  Future<OneSignalClientState> getState();
  Future<void> requestPermission({required bool fallbackToSettings});
  Future<void> optIn();
  Future<void> optOut();
  Future<void> login(String externalUserId);
  Future<void> logout();
  Future<void> setTags(Map<String, String> tags);
  Future<void> removeTags(List<String> keys);
  void addPermissionListener(OneSignalStateListener listener);
  void removePermissionListener(OneSignalStateListener listener);
  void addSubscriptionListener(OneSignalStateListener listener);
  void removeSubscriptionListener(OneSignalStateListener listener);
  void addForegroundListener(OneSignalMessageListener listener);
  void removeForegroundListener(OneSignalMessageListener listener);
  void addClickListener(OneSignalMessageListener listener);
  void removeClickListener(OneSignalMessageListener listener);
}

/// Default bridge backed by `onesignal_flutter`.
final class DefaultOneSignalClient implements OneSignalClient {
  final Map<OneSignalStateListener, OnNotificationPermissionChangeObserver>
      _permissionListeners =
      <OneSignalStateListener, OnNotificationPermissionChangeObserver>{};
  final Map<OneSignalStateListener, OnPushSubscriptionChangeObserver>
      _subscriptionListeners =
      <OneSignalStateListener, OnPushSubscriptionChangeObserver>{};
  final Map<OneSignalMessageListener, OnNotificationWillDisplayListener>
      _foregroundListeners =
      <OneSignalMessageListener, OnNotificationWillDisplayListener>{};
  final Map<OneSignalMessageListener, OnNotificationClickListener>
      _clickListeners =
      <OneSignalMessageListener, OnNotificationClickListener>{};

  @override
  Future<void> configurePrivacy({
    required bool consentRequired,
    required bool? consentGranted,
  }) async {
    await OneSignal.consentRequired(consentRequired);
    if (consentGranted != null) {
      await OneSignal.consentGiven(consentGranted);
    }
  }

  @override
  Future<void> setVerboseLogging(bool enabled) => OneSignal.Debug.setLogLevel(
        enabled ? OSLogLevel.verbose : OSLogLevel.none,
      );

  @override
  void initialize(String appId) => OneSignal.initialize(appId);

  @override
  Future<OneSignalClientState> getState() async {
    final nativePermission = await OneSignal.Notifications.permissionNative();
    final permission = switch (nativePermission) {
      OSNotificationPermission.notDetermined =>
        OneSignalClientPermission.notDetermined,
      OSNotificationPermission.denied => OneSignalClientPermission.denied,
      OSNotificationPermission.authorized =>
        OneSignalClientPermission.authorized,
      OSNotificationPermission.provisional =>
        OneSignalClientPermission.provisional,
      OSNotificationPermission.ephemeral => OneSignalClientPermission.ephemeral,
    };
    return OneSignalClientState(
      permission: permission,
      canRequestPermission: await OneSignal.Notifications.canRequest(),
      optedIn: OneSignal.User.pushSubscription.optedIn,
      subscriptionId: OneSignal.User.pushSubscription.id,
      pushToken: OneSignal.User.pushSubscription.token,
      externalUserId: await OneSignal.User.getExternalId(),
    );
  }

  @override
  Future<void> requestPermission({required bool fallbackToSettings}) async {
    await OneSignal.Notifications.requestPermission(fallbackToSettings);
  }

  @override
  Future<void> optIn() => OneSignal.User.pushSubscription.optIn();

  @override
  Future<void> optOut() => OneSignal.User.pushSubscription.optOut();

  @override
  Future<void> login(String externalUserId) => OneSignal.login(externalUserId);

  @override
  Future<void> logout() => OneSignal.logout();

  @override
  Future<void> setTags(Map<String, String> tags) =>
      OneSignal.User.addTags(tags);

  @override
  Future<void> removeTags(List<String> keys) => OneSignal.User.removeTags(keys);

  @override
  void addPermissionListener(OneSignalStateListener listener) {
    void observer(bool _) => listener();
    _permissionListeners[listener] = observer;
    OneSignal.Notifications.addPermissionObserver(observer);
  }

  @override
  void removePermissionListener(OneSignalStateListener listener) {
    final observer = _permissionListeners.remove(listener);
    if (observer != null) {
      OneSignal.Notifications.removePermissionObserver(observer);
    }
  }

  @override
  void addSubscriptionListener(OneSignalStateListener listener) {
    void observer(OSPushSubscriptionChangedState _) => listener();
    _subscriptionListeners[listener] = observer;
    OneSignal.User.pushSubscription.addObserver(observer);
  }

  @override
  void removeSubscriptionListener(OneSignalStateListener listener) {
    final observer = _subscriptionListeners.remove(listener);
    if (observer != null) {
      OneSignal.User.pushSubscription.removeObserver(observer);
    }
  }

  @override
  void addForegroundListener(OneSignalMessageListener listener) {
    void sdkListener(OSNotificationWillDisplayEvent event) {
      listener(_mapMessage(event.notification));
    }

    _foregroundListeners[listener] = sdkListener;
    OneSignal.Notifications.addForegroundWillDisplayListener(sdkListener);
  }

  @override
  void removeForegroundListener(OneSignalMessageListener listener) {
    final sdkListener = _foregroundListeners.remove(listener);
    if (sdkListener != null) {
      OneSignal.Notifications.removeForegroundWillDisplayListener(sdkListener);
    }
  }

  @override
  void addClickListener(OneSignalMessageListener listener) {
    void sdkListener(OSNotificationClickEvent event) {
      listener(
          _mapMessage(event.notification, actionId: event.result.actionId));
    }

    _clickListeners[listener] = sdkListener;
    OneSignal.Notifications.addClickListener(sdkListener);
  }

  @override
  void removeClickListener(OneSignalMessageListener listener) {
    final sdkListener = _clickListeners.remove(listener);
    if (sdkListener != null) {
      OneSignal.Notifications.removeClickListener(sdkListener);
    }
  }

  OneSignalClientMessage _mapMessage(
    OSNotification notification, {
    String? actionId,
  }) {
    return OneSignalClientMessage(
      id: notification.notificationId,
      title: notification.title,
      body: notification.body,
      actionId: actionId,
      additionalData: Map<String, Object?>.unmodifiable(
        notification.additionalData ?? const <String, Object?>{},
      ),
    );
  }
}
