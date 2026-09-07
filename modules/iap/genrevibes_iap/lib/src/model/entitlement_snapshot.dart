import 'entitlement.dart';

/// A point-in-time view of all entitlements for the current customer.
final class EntitlementSnapshot {
  /// Creates an entitlement snapshot.
  const EntitlementSnapshot({
    required this.entitlements,
    required this.observedAt,
    required this.provider,
    this.appUserId,
  });

  /// Entitlements returned by the provider, including inactive records.
  final List<Entitlement> entitlements;

  /// Time at which the provider state was observed.
  final DateTime observedAt;

  /// Adapter identifier such as `revenuecat` or `adapty`.
  final String provider;

  /// Stable application user identifier when the customer is identified.
  final String? appUserId;

  /// Active entitlement identifiers.
  Set<String> get activeEntitlementIds => entitlements
      .where((entitlement) => entitlement.isActive)
      .map((entitlement) => entitlement.id)
      .toSet();

  /// Whether [entitlementId] is currently active.
  bool hasActiveEntitlement(String entitlementId) =>
      activeEntitlementIds.contains(entitlementId);
}
