/// Operating-system notification permission as reported by a push provider.
enum PushPermissionStatus {
  /// The adapter cannot determine the current permission.
  unknown,

  /// The operating system has not asked the user yet.
  notDetermined,

  /// The user or operating system denied notification permission.
  denied,

  /// Full notification permission was granted.
  authorized,

  /// Quiet/provisional delivery was granted on a supported platform.
  provisional,

  /// Temporary notification permission was granted on a supported platform.
  ephemeral,
}

/// A reason why remote push delivery is not currently healthy.
enum PushDeliveryIssue {
  /// Notification permission is not granted.
  permissionNotGranted,

  /// The provider subscription was explicitly or implicitly opted out.
  providerOptedOut,

  /// The provider has not assigned a subscription identifier.
  missingSubscriptionId,

  /// The device has not received a platform push token.
  missingPushToken,
}

/// Complete, non-secret diagnostic state for one device push subscription.
final class PushSubscriptionState {
  /// Creates an immutable push subscription snapshot.
  const PushSubscriptionState({
    required this.providerId,
    required this.permission,
    required this.canRequestPermission,
    required this.optedIn,
    this.subscriptionId,
    this.pushToken,
    this.externalUserId,
    this.observedAt,
  });

  /// Stable provider name such as `onesignal`.
  final String providerId;

  /// Current operating-system notification permission.
  final PushPermissionStatus permission;

  /// Whether another native permission prompt may be presented.
  final bool canRequestPermission;

  /// Provider-level opt-in state, or null while the SDK is resolving it.
  final bool? optedIn;

  /// Provider subscription identifier. This is not an application user ID.
  final String? subscriptionId;

  /// APNs/FCM push token when available. Never write this value to logs.
  final String? pushToken;

  /// Application identity currently associated with the provider.
  final String? externalUserId;

  /// Time at which this snapshot was read.
  final DateTime? observedAt;

  /// Whether the OS has granted a form of usable notification permission.
  bool get hasPermission =>
      permission == PushPermissionStatus.authorized ||
      permission == PushPermissionStatus.provisional ||
      permission == PushPermissionStatus.ephemeral;

  /// Whether all observable prerequisites for remote delivery are present.
  bool get isDeliverable => issues.isEmpty;

  /// Actionable delivery issues, intentionally kept separate from logging.
  Set<PushDeliveryIssue> get issues {
    return <PushDeliveryIssue>{
      if (!hasPermission) PushDeliveryIssue.permissionNotGranted,
      if (optedIn != true) PushDeliveryIssue.providerOptedOut,
      if (subscriptionId == null || subscriptionId!.trim().isEmpty)
        PushDeliveryIssue.missingSubscriptionId,
      if (pushToken == null || pushToken!.trim().isEmpty)
        PushDeliveryIssue.missingPushToken,
    };
  }

  /// Safe diagnostic fields that deliberately omit IDs and push tokens.
  Map<String, Object?> toSafeDiagnostics() => <String, Object?>{
        'provider': providerId,
        'permission': permission.name,
        'canRequestPermission': canRequestPermission,
        'optedIn': optedIn,
        'hasSubscriptionId':
            subscriptionId != null && subscriptionId!.trim().isNotEmpty,
        'hasPushToken': pushToken != null && pushToken!.trim().isNotEmpty,
        'hasExternalUserId':
            externalUserId != null && externalUserId!.trim().isNotEmpty,
        'deliverable': isDeliverable,
        'issues': issues.map((issue) => issue.name).toList(growable: false),
      };
}
