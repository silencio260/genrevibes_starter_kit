import 'package:genrevibes_iap/genrevibes_iap.dart';

/// Optional bridge implemented by the separate RevenueCat UI adapter.
abstract interface class RevenueCatUiPresenter {
  /// Presents a RevenueCat paywall and returns its normalized outcome.
  Future<PurchaseStatus> presentPaywall({
    String? placementId,
    String? requiredEntitlementId,
  });

  /// Presents RevenueCat customer-center UI.
  Future<void> presentCustomerCenter();
}
