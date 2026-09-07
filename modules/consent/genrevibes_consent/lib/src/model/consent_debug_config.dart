/// Region a consent platform should simulate while testing.
enum ConsentDebugGeography {
  /// Use the device's real location.
  disabled,

  /// Behave as if the device is inside the European Economic Area.
  europeanEconomicArea,

  /// Behave as if the device is outside any regulated region.
  notRegulated,
}

/// Test-only consent overrides, expressed without a vendor type.
///
/// Adapters translate this into whatever their SDK expects. Keeping the shape
/// here means application code never imports a consent vendor to configure
/// testing, and never has to change when the vendor does.
///
/// This must not be supplied in a production build: forcing a geography
/// presents the form to users who would not otherwise see it.
final class ConsentDebugConfig {
  /// Creates a debug configuration.
  const ConsentDebugConfig({
    this.geography = ConsentDebugGeography.disabled,
    this.testDeviceIds = const <String>[],
  });

  /// Region to simulate.
  final ConsentDebugGeography geography;

  /// Hashed device identifiers the platform should treat as test devices.
  final List<String> testDeviceIds;

  /// Whether this configuration changes any platform behavior.
  bool get isActive =>
      geography != ConsentDebugGeography.disabled || testDeviceIds.isNotEmpty;
}
