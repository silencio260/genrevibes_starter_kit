/// Ownership classifications normalized across IAP providers.
enum EntitlementOwnership {
  /// Purchased by the current store account.
  purchased,

  /// Shared through a family or household mechanism.
  familyShared,

  /// Granted promotionally by the provider or application.
  promotional,

  /// The provider did not expose a recognized ownership type.
  unknown,
}

/// A provider-neutral entitlement granted to the current customer.
final class Entitlement {
  /// Creates an entitlement.
  const Entitlement({
    required this.id,
    required this.productId,
    required this.isActive,
    required this.observedAt,
    this.expiresAt,
    this.willRenew,
    this.ownership = EntitlementOwnership.unknown,
    this.isSandbox = false,
    this.metadata = const <String, Object?>{},
  });

  /// Stable entitlement identifier used by application access policy.
  final String id;

  /// Store product that granted this entitlement.
  final String productId;

  /// Whether the entitlement is active at [observedAt].
  final bool isActive;

  /// Time at which the provider state was observed.
  final DateTime observedAt;

  /// Entitlement expiration, or `null` for a permanent entitlement.
  final DateTime? expiresAt;

  /// Whether the subscription is expected to renew.
  final bool? willRenew;

  /// How the customer obtained the entitlement.
  final EntitlementOwnership ownership;

  /// Whether the transaction came from a sandbox environment.
  final bool isSandbox;

  /// Additional non-essential provider fields.
  final Map<String, Object?> metadata;
}
