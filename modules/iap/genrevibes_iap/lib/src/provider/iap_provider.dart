import 'package:genrevibes_core/genrevibes_core.dart';

import '../model/entitlement_snapshot.dart';
import '../model/iap_capabilities.dart';
import '../model/iap_product.dart';
import '../model/purchase_result.dart';

/// Contract implemented by RevenueCat, Adapty, and future IAP adapters.
abstract interface class IapProvider implements StarterModule {
  /// Stable provider identifier such as `revenuecat`.
  String get providerId;

  /// Optional behaviors implemented by this adapter.
  IapCapabilities get capabilities;

  /// Emits refreshed entitlement snapshots throughout the app lifecycle.
  Stream<EntitlementSnapshot> get entitlementChanges;

  /// Returns available products.
  ///
  /// Empty [productIds] permits an adapter to return its current offering.
  Future<KitResult<List<IapProduct>>> getProducts({
    Set<String> productIds = const <String>{},
    String? placementId,
  });

  /// Starts a direct purchase for [productId].
  Future<KitResult<PurchaseResult>> purchase(String productId);

  /// Presents provider-hosted paywall UI when supported.
  Future<KitResult<PurchaseResult>> presentPaywall({
    String? placementId,
    String? requiredEntitlementId,
  });

  /// Presents provider-hosted customer management UI when supported.
  Future<KitResult<void>> presentCustomerCenter();

  /// Restores store purchases and returns refreshed entitlements.
  Future<KitResult<EntitlementSnapshot>> restorePurchases();

  /// Returns the current entitlement state.
  Future<KitResult<EntitlementSnapshot>> getEntitlements({
    bool forceRefresh = false,
  });

  /// Associates purchases with a stable application user identifier.
  Future<KitResult<EntitlementSnapshot>> identify(String appUserId);

  /// Ends the identified session and returns the new customer state.
  Future<KitResult<EntitlementSnapshot>> resetIdentity();
}
