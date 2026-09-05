import 'entitlement_snapshot.dart';

/// Outcomes that are not represented as provider failures.
enum PurchaseStatus {
  /// The purchase completed and the entitlement snapshot was refreshed.
  purchased,

  /// The customer cancelled without purchasing.
  cancelled,

  /// Store approval or processing is still pending.
  pending,

  /// Purchases were restored by a paywall flow.
  restored,

  /// A hosted paywall closed without a transaction.
  notPurchased,
}

/// The normalized outcome of a direct or provider-hosted purchase flow.
final class PurchaseResult {
  /// Creates a purchase result.
  const PurchaseResult({
    required this.status,
    this.productId,
    this.entitlements,
  });

  /// Normalized purchase outcome.
  final PurchaseStatus status;

  /// Purchased product when known.
  final String? productId;

  /// Refreshed entitlement state when supplied by the provider.
  final EntitlementSnapshot? entitlements;
}
