import 'package:genrevibes_consent/genrevibes_consent.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Translates a UMP consent status into the neutral [ConsentState].
///
/// This describes the consent *flow* only. In particular
/// [ConsentStatus.obtained] means the user answered the form, not that they
/// agreed: whether ads may be requested comes from `UmpClient.canRequestAds`,
/// and personalization is the ad network's decision, taken from the consent
/// string without the application's involvement.
ConsentState mapUmpConsentStatus(ConsentStatus status) {
  return switch (status) {
    ConsentStatus.obtained => ConsentState.obtained,
    ConsentStatus.notRequired => ConsentState.notRequired,
    ConsentStatus.required => ConsentState.consentRequired,
    ConsentStatus.unknown => ConsentState.unknown,
  };
}

/// Whether the app must expose a persistent privacy-options entry point.
bool mapUmpPrivacyOptionsRequired(PrivacyOptionsRequirementStatus status) {
  return status == PrivacyOptionsRequirementStatus.required;
}

/// Translates neutral debug settings into UMP request parameters.
///
/// Returns default parameters when [config] is inactive, so a production build
/// never forces a geography.
ConsentRequestParameters mapUmpDebugConfig(ConsentDebugConfig config) {
  if (!config.isActive) return ConsentRequestParameters();
  return ConsentRequestParameters(
    consentDebugSettings: ConsentDebugSettings(
      debugGeography: _mapGeography(config.geography),
      testIdentifiers: config.testDeviceIds,
    ),
  );
}

DebugGeography _mapGeography(ConsentDebugGeography geography) {
  switch (geography) {
    case ConsentDebugGeography.europeanEconomicArea:
      return DebugGeography.debugGeographyEea;
    case ConsentDebugGeography.notRegulated:
      // `debugGeographyOther` supersedes this in google_mobile_ads 9.x but does
      // not exist at this adapter's declared floor of 5.3.1. Keep the
      // deprecated value until that floor rises, or the adapter stops
      // compiling against the minimum version it advertises.
      // ignore: deprecated_member_use
      return DebugGeography.debugGeographyNotEea;
    case ConsentDebugGeography.disabled:
      return DebugGeography.debugGeographyDisabled;
  }
}
