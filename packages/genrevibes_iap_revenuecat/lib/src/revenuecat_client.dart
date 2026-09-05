import 'package:purchases_flutter/purchases_flutter.dart' as revenuecat;

/// Injectable boundary around the static RevenueCat SDK API.
///
/// Applications normally use [DefaultRevenueCatClient]. The abstraction allows
/// adapter behavior to be contract-tested without creating real transactions.
abstract interface class RevenueCatClient {
  /// Sets RevenueCat SDK logging verbosity.
  Future<void> setLogLevel(revenuecat.LogLevel level);

  /// Whether the global RevenueCat SDK is already configured.
  Future<bool> isConfigured();

  /// Configures the RevenueCat SDK.
  Future<void> configure(revenuecat.PurchasesConfiguration configuration);

  /// Registers a customer information listener.
  void addCustomerInfoUpdateListener(
    revenuecat.CustomerInfoUpdateListener listener,
  );

  /// Removes a previously registered customer information listener.
  void removeCustomerInfoUpdateListener(
    revenuecat.CustomerInfoUpdateListener listener,
  );

  /// Returns current customer information.
  Future<revenuecat.CustomerInfo> getCustomerInfo();

  /// Returns store products matching [productIds].
  Future<List<revenuecat.StoreProduct>> getProducts(List<String> productIds);

  /// Returns configured RevenueCat offerings.
  Future<revenuecat.Offerings> getOfferings();

  /// Returns the current offering for a targeting placement.
  Future<revenuecat.Offering?> getCurrentOfferingForPlacement(
    String placementId,
  );

  /// Purchases [product].
  Future<revenuecat.PurchaseResult> purchase(revenuecat.StoreProduct product);

  /// Restores purchases and returns refreshed customer information.
  Future<revenuecat.CustomerInfo> restorePurchases();

  /// Invalidates cached customer information.
  Future<void> invalidateCustomerInfoCache();

  /// Identifies the current customer and returns merged customer information.
  Future<revenuecat.CustomerInfo> logIn(String appUserId);

  /// Returns the customer to an anonymous identity.
  Future<revenuecat.CustomerInfo> logOut();
}

/// Production [RevenueCatClient] backed by `purchases_flutter`.
final class DefaultRevenueCatClient implements RevenueCatClient {
  /// Creates the production RevenueCat client.
  const DefaultRevenueCatClient();

  @override
  void addCustomerInfoUpdateListener(
    revenuecat.CustomerInfoUpdateListener listener,
  ) {
    revenuecat.Purchases.addCustomerInfoUpdateListener(listener);
  }

  @override
  Future<void> configure(revenuecat.PurchasesConfiguration configuration) {
    return revenuecat.Purchases.configure(configuration);
  }

  @override
  Future<revenuecat.CustomerInfo> getCustomerInfo() {
    return revenuecat.Purchases.getCustomerInfo();
  }

  @override
  Future<revenuecat.Offering?> getCurrentOfferingForPlacement(
    String placementId,
  ) {
    return revenuecat.Purchases.getCurrentOfferingForPlacement(placementId);
  }

  @override
  Future<revenuecat.Offerings> getOfferings() {
    return revenuecat.Purchases.getOfferings();
  }

  @override
  Future<List<revenuecat.StoreProduct>> getProducts(List<String> productIds) {
    return revenuecat.Purchases.getProducts(productIds);
  }

  @override
  Future<void> invalidateCustomerInfoCache() {
    return revenuecat.Purchases.invalidateCustomerInfoCache();
  }

  @override
  Future<bool> isConfigured() => revenuecat.Purchases.isConfigured;

  @override
  Future<revenuecat.CustomerInfo> logIn(String appUserId) async {
    final result = await revenuecat.Purchases.logIn(appUserId);
    return result.customerInfo;
  }

  @override
  Future<revenuecat.CustomerInfo> logOut() => revenuecat.Purchases.logOut();

  @override
  Future<revenuecat.PurchaseResult> purchase(
    revenuecat.StoreProduct product,
  ) {
    return revenuecat.Purchases.purchase(
      revenuecat.PurchaseParams.storeProduct(product),
    );
  }

  @override
  void removeCustomerInfoUpdateListener(
    revenuecat.CustomerInfoUpdateListener listener,
  ) {
    revenuecat.Purchases.removeCustomerInfoUpdateListener(listener);
  }

  @override
  Future<revenuecat.CustomerInfo> restorePurchases() {
    return revenuecat.Purchases.restorePurchases();
  }

  @override
  Future<void> setLogLevel(revenuecat.LogLevel level) {
    return revenuecat.Purchases.setLogLevel(level);
  }
}
