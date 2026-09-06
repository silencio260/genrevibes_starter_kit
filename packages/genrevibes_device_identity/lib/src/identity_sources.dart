import 'device_identity.dart';

/// Reads the platform advertising identifier behind a consent prompt.
abstract interface class AdvertisingIdSource {
  /// Current authorization without prompting.
  Future<TrackingAuthorization> authorization();

  /// Prompts the user (where the platform requires it) and returns the result.
  Future<TrackingAuthorization> requestAuthorization();

  /// The advertising identifier, or `null` when unavailable or all zeros.
  Future<String?> advertisingId();
}

/// Reads the platform vendor identifier.
abstract interface class VendorIdSource {
  /// The vendor identifier, or `null` when the platform has none.
  Future<String?> vendorId();
}

/// [AdvertisingIdSource] for platforms without tracking authorization.
final class UnsupportedAdvertisingIdSource implements AdvertisingIdSource {
  /// Creates the source.
  const UnsupportedAdvertisingIdSource();

  @override
  Future<TrackingAuthorization> authorization() async =>
      TrackingAuthorization.notSupported;

  @override
  Future<TrackingAuthorization> requestAuthorization() async =>
      TrackingAuthorization.notSupported;

  @override
  Future<String?> advertisingId() async => null;
}

/// [VendorIdSource] that reports no identifier.
final class NoVendorIdSource implements VendorIdSource {
  /// Creates the source.
  const NoVendorIdSource();

  @override
  Future<String?> vendorId() async => null;
}
