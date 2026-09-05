import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_iap/genrevibes_iap.dart';
import 'package:genrevibes_iap_revenuecat/src/revenuecat_mapper.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as revenuecat;

void main() {
  test('maps RevenueCat subscription products without leaking vendor models',
      () {
    const product = revenuecat.StoreProduct(
      'pro.monthly',
      'Monthly premium access',
      'Pro monthly',
      4.99,
      r'$4.99',
      'USD',
      productCategory: revenuecat.ProductCategory.subscription,
      subscriptionPeriod: 'P1M',
    );

    final mapped = mapRevenueCatProduct(
      product,
      offeringId: 'default',
      packageId: r'$rc_monthly',
    );

    expect(mapped.id, 'pro.monthly');
    expect(mapped.type, IapProductType.subscription);
    expect(mapped.billingPeriodIso8601, 'P1M');
    expect(mapped.offeringId, 'default');
    expect(mapped.packageId, r'$rc_monthly');
  });

  test('maps active RevenueCat entitlements and customer identity', () {
    const entitlement = revenuecat.EntitlementInfo(
      'pro',
      true,
      true,
      '2026-09-01T00:00:00Z',
      '2026-09-01T00:00:00Z',
      'pro.monthly',
      false,
      ownershipType: revenuecat.OwnershipType.purchased,
      expirationDate: '2026-10-01T00:00:00Z',
    );
    const info = revenuecat.CustomerInfo(
      revenuecat.EntitlementInfos(
        <String, revenuecat.EntitlementInfo>{'pro': entitlement},
        <String, revenuecat.EntitlementInfo>{'pro': entitlement},
      ),
      <String, String?>{},
      <String>['pro.monthly'],
      <String>['pro.monthly'],
      <revenuecat.StoreTransaction>[],
      '2026-09-01T00:00:00Z',
      'portfolio-user-1',
      <String, String?>{},
      '2026-09-05T12:00:00Z',
    );

    final mapped = mapRevenueCatCustomerInfo(info);

    expect(mapped.provider, 'revenuecat');
    expect(mapped.appUserId, 'portfolio-user-1');
    expect(mapped.hasActiveEntitlement('pro'), isTrue);
    expect(mapped.entitlements.single.productId, 'pro.monthly');
    expect(
        mapped.entitlements.single.ownership, EntitlementOwnership.purchased);
  });
}
