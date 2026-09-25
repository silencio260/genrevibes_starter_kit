/// Application-owned Yodo1 MAS settings.
///
/// Everything else about the mediation stack — which networks bid, waterfall
/// order, banner position, test devices — is configured in the MAS dashboard,
/// not here. The SDK has no runtime API for any of it.
final class GenRevibesYodo1Configuration {
  /// Creates Yodo1 MAS configuration.
  const GenRevibesYodo1Configuration({
    required this.appKey,
    this.useMasPrivacyDialog = true,
    this.ccpaOptOut = false,
    this.coppaAgeRestricted = false,
    this.gdprConsentGranted = false,
    this.initializationTimeout = const Duration(seconds: 20),
  });

  /// App key from the MAS dashboard. Blank leaves the provider unconfigured.
  final String appKey;

  /// Whether MAS shows its own privacy dialog.
  ///
  /// This is the ad network's consent form. It is the only consent surface in
  /// this portfolio; product analytics is never gated on it.
  final bool useMasPrivacyDialog;

  /// CCPA: whether this user opted out of the sale of personal information.
  final bool ccpaOptOut;

  /// COPPA: whether this user is age-restricted.
  final bool coppaAgeRestricted;

  /// GDPR: whether this user granted consent, when the app collects it
  /// instead of [useMasPrivacyDialog].
  final bool gdprConsentGranted;

  /// How long initialization waits for the SDK's init callback.
  final Duration initializationTimeout;

  /// Whether an app key was supplied.
  bool get isConfigured => appKey.trim().isNotEmpty;
}
