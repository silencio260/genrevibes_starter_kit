import 'package:genrevibes_iap/genrevibes_iap.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as revenuecat;

/// Converts a RevenueCat store product into the provider-neutral model.
IapProduct mapRevenueCatProduct(
  revenuecat.StoreProduct product, {
  String? offeringId,
  String? packageId,
}) {
  final category = product.productCategory;
  final type = switch (category) {
    revenuecat.ProductCategory.nonSubscription => IapProductType.nonConsumable,
    revenuecat.ProductCategory.subscription => IapProductType.subscription,
    null => IapProductType.unknown,
  };

  return IapProduct(
    id: product.identifier,
    title: product.title,
    description: product.description,
    type: type,
    price: product.price,
    priceString: product.priceString,
    currencyCode: product.currencyCode,
    offeringId: offeringId,
    packageId: packageId,
    billingPeriodIso8601: product.subscriptionPeriod,
  );
}

/// Converts RevenueCat customer information into an entitlement snapshot.
EntitlementSnapshot mapRevenueCatCustomerInfo(
  revenuecat.CustomerInfo customerInfo,
) {
  final observedAt = DateTime.tryParse(customerInfo.requestDate)?.toUtc() ??
      DateTime.now().toUtc();
  final entitlements = customerInfo.entitlements.all.values.map((entitlement) {
    return Entitlement(
      id: entitlement.identifier,
      productId: entitlement.productIdentifier,
      isActive: entitlement.isActive,
      observedAt: observedAt,
      expiresAt: _parseDate(entitlement.expirationDate),
      willRenew: entitlement.willRenew,
      ownership: switch (entitlement.ownershipType) {
        revenuecat.OwnershipType.purchased => EntitlementOwnership.purchased,
        revenuecat.OwnershipType.familyShared =>
          EntitlementOwnership.familyShared,
        revenuecat.OwnershipType.unknown => EntitlementOwnership.unknown,
      },
      isSandbox: entitlement.isSandbox,
      metadata: <String, Object?>{
        'store': entitlement.store.name,
        'period_type': entitlement.periodType.name,
        'verification': entitlement.verification.name,
      },
    );
  }).toList(growable: false);

  return EntitlementSnapshot(
    entitlements: entitlements,
    observedAt: observedAt,
    provider: 'revenuecat',
    appUserId: customerInfo.originalAppUserId,
  );
}

DateTime? _parseDate(String? value) {
  if (value == null) return null;
  return DateTime.tryParse(value)?.toUtc();
}
