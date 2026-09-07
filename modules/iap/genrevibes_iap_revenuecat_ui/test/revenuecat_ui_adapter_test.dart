import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_iap/genrevibes_iap.dart';
import 'package:genrevibes_iap_revenuecat_ui/genrevibes_iap_revenuecat_ui.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

void main() {
  test('maps completed RevenueCat paywall results', () {
    expect(
      mapRevenueCatPaywallResult(PaywallResult.purchased),
      PurchaseStatus.purchased,
    );
    expect(
      mapRevenueCatPaywallResult(PaywallResult.restored),
      PurchaseStatus.restored,
    );
    expect(
      mapRevenueCatPaywallResult(PaywallResult.cancelled),
      PurchaseStatus.cancelled,
    );
    expect(
      mapRevenueCatPaywallResult(PaywallResult.notPresented),
      PurchaseStatus.notPurchased,
    );
  });

  test('maps RevenueCat UI errors to a typed exception', () {
    expect(
      () => mapRevenueCatPaywallResult(PaywallResult.error),
      throwsA(isA<RevenueCatUiException>()),
    );
  });
}
