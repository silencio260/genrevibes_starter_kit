import 'package:genrevibes_iap/genrevibes_iap.dart';
import 'package:genrevibes_iap_revenuecat/genrevibes_iap_revenuecat.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// Error reported when RevenueCat UI returns its generic error outcome.
final class RevenueCatUiException implements Exception {
  /// Creates a RevenueCat UI error.
  const RevenueCatUiException(this.message);

  /// Diagnostic description of the failed UI operation.
  final String message;

  @override
  String toString() => 'RevenueCatUiException: $message';
}

/// Presents RevenueCat-hosted paywalls and customer-center UI.
final class RevenueCatUiAdapter implements RevenueCatUiPresenter {
  /// Creates a RevenueCat UI adapter.
  const RevenueCatUiAdapter({this.displayCloseButton = false});

  /// Whether supported paywall templates display their close button.
  final bool displayCloseButton;

  @override
  Future<PurchaseStatus> presentPaywall({
    String? placementId,
    String? requiredEntitlementId,
  }) async {
    final offering = await _resolveOffering(placementId);
    final result = requiredEntitlementId == null
        ? await RevenueCatUI.presentPaywall(
            offering: offering,
            displayCloseButton: displayCloseButton,
          )
        : await RevenueCatUI.presentPaywallIfNeeded(
            requiredEntitlementId,
            offering: offering,
            displayCloseButton: displayCloseButton,
          );
    return mapRevenueCatPaywallResult(result);
  }

  @override
  Future<void> presentCustomerCenter() => RevenueCatUI.presentCustomerCenter();

  Future<Offering?> _resolveOffering(String? placementId) async {
    if (placementId != null && placementId.trim().isNotEmpty) {
      return Purchases.getCurrentOfferingForPlacement(placementId.trim());
    }
    return null;
  }
}

/// Converts RevenueCat UI results into provider-neutral purchase outcomes.
PurchaseStatus mapRevenueCatPaywallResult(PaywallResult result) {
  return switch (result) {
    PaywallResult.purchased => PurchaseStatus.purchased,
    PaywallResult.restored => PurchaseStatus.restored,
    PaywallResult.cancelled => PurchaseStatus.cancelled,
    PaywallResult.notPresented => PurchaseStatus.notPurchased,
    PaywallResult.error => throw const RevenueCatUiException(
        'RevenueCat could not present or complete the paywall.',
      ),
  };
}
