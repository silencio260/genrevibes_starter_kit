/// OneSignal initialization policy owned by the host application.
final class GenRevibesOneSignalConfiguration {
  /// Creates OneSignal configuration.
  const GenRevibesOneSignalConfiguration({
    required this.appId,
    this.verboseLogging = false,
    this.consentRequired = false,
    this.consentGranted,
  });

  /// OneSignal application identifier.
  final String appId;

  /// Enables verbose SDK logs for deliberate development diagnostics.
  final bool verboseLogging;

  /// Prevents SDK collection until consent is granted.
  final bool consentRequired;

  /// Initial privacy consent, when the host has already made a decision.
  final bool? consentGranted;
}
