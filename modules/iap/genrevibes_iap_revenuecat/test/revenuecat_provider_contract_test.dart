import 'package:genrevibes_iap_revenuecat/genrevibes_iap_revenuecat.dart';
import 'package:genrevibes_iap_test/genrevibes_iap_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as revenuecat;

void main() {
  runIapProviderContractTests(
    scenario: const IapProviderContractScenario(
      providerName: 'RevenueCat',
      productId: 'pro.monthly',
      appUserId: 'portfolio-user-1',
    ),
    createProvider: () async => RevenueCatIapProvider(
      configuration: const RevenueCatConfiguration(
        androidApiKey: 'test_android_key',
        iosApiKey: 'test_apple_key',
        macosApiKey: 'test_macos_key',
        webApiKey: 'test_web_key',
      ),
      client: _FakeRevenueCatClient(),
    ),
  );
}

final class _FakeRevenueCatClient implements RevenueCatClient {
  static const revenuecat.StoreProduct product = revenuecat.StoreProduct(
    'pro.monthly',
    'Monthly premium access',
    'Pro monthly',
    4.99,
    r'$4.99',
    'USD',
    productCategory: revenuecat.ProductCategory.subscription,
    subscriptionPeriod: 'P1M',
  );

  bool _configured = false;
  String _appUserId = r'$RCAnonymousID:test';
  bool _purchased = false;
  final List<revenuecat.CustomerInfoUpdateListener> _listeners =
      <revenuecat.CustomerInfoUpdateListener>[];

  @override
  void addCustomerInfoUpdateListener(
    revenuecat.CustomerInfoUpdateListener listener,
  ) {
    _listeners.add(listener);
  }

  @override
  Future<void> configure(
      revenuecat.PurchasesConfiguration configuration) async {
    _configured = true;
    _appUserId = configuration.appUserID ?? _appUserId;
  }

  @override
  Future<revenuecat.CustomerInfo> getCustomerInfo() async => _customerInfo();

  @override
  Future<revenuecat.Offering?> getCurrentOfferingForPlacement(
    String placementId,
  ) async =>
      null;

  @override
  Future<revenuecat.Offerings> getOfferings() async {
    return const revenuecat.Offerings(<String, revenuecat.Offering>{});
  }

  @override
  Future<List<revenuecat.StoreProduct>> getProducts(
    List<String> productIds,
  ) async {
    return productIds.contains(product.identifier)
        ? const <revenuecat.StoreProduct>[product]
        : const <revenuecat.StoreProduct>[];
  }

  @override
  Future<void> invalidateCustomerInfoCache() async {}

  @override
  Future<bool> isConfigured() async => _configured;

  @override
  Future<revenuecat.CustomerInfo> logIn(String appUserId) async {
    _appUserId = appUserId;
    return _notify();
  }

  @override
  Future<revenuecat.CustomerInfo> logOut() async {
    _appUserId = r'$RCAnonymousID:reset';
    return _notify();
  }

  @override
  Future<revenuecat.PurchaseResult> purchase(
    revenuecat.StoreProduct product,
  ) async {
    _purchased = true;
    final customerInfo = await _notify();
    return revenuecat.PurchaseResult(
      customerInfo,
      revenuecat.StoreTransaction(
        'transaction-1',
        product.identifier,
        '2026-09-05T12:00:00Z',
      ),
    );
  }

  @override
  void removeCustomerInfoUpdateListener(
    revenuecat.CustomerInfoUpdateListener listener,
  ) {
    _listeners.remove(listener);
  }

  @override
  Future<revenuecat.CustomerInfo> restorePurchases() async => _notify();

  @override
  Future<void> setLogLevel(revenuecat.LogLevel level) async {}

  Future<revenuecat.CustomerInfo> _notify() async {
    final info = _customerInfo();
    for (final listener in List<revenuecat.CustomerInfoUpdateListener>.of(
      _listeners,
    )) {
      listener(info);
    }
    return info;
  }

  revenuecat.CustomerInfo _customerInfo() {
    const entitlement = revenuecat.EntitlementInfo(
      'pro',
      true,
      true,
      '2026-09-05T12:00:00Z',
      '2026-09-05T12:00:00Z',
      'pro.monthly',
      false,
      ownershipType: revenuecat.OwnershipType.purchased,
      expirationDate: '2026-10-05T12:00:00Z',
    );
    final all = _purchased
        ? const <String, revenuecat.EntitlementInfo>{'pro': entitlement}
        : const <String, revenuecat.EntitlementInfo>{};
    return revenuecat.CustomerInfo(
      revenuecat.EntitlementInfos(all, all),
      const <String, String?>{},
      _purchased ? const <String>['pro.monthly'] : const <String>[],
      _purchased ? const <String>['pro.monthly'] : const <String>[],
      const <revenuecat.StoreTransaction>[],
      '2026-09-05T12:00:00Z',
      _appUserId,
      const <String, String?>{},
      '2026-09-05T12:00:00Z',
    );
  }
}
