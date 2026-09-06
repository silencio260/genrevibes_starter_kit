import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart'
    as att;
import 'package:genrevibes_device_identity/genrevibes_device_identity.dart';

/// Injectable boundary around the App Tracking Transparency plugin.
abstract interface class TrackingClient {
  /// Current status without prompting.
  Future<att.TrackingStatus> status();

  /// Prompts and returns the resulting status.
  Future<att.TrackingStatus> request();

  /// The advertising identifier.
  Future<String> advertisingIdentifier();
}

/// Production tracking client.
final class DefaultTrackingClient implements TrackingClient {
  /// Creates a client.
  const DefaultTrackingClient();

  @override
  Future<att.TrackingStatus> status() =>
      att.AppTrackingTransparency.trackingAuthorizationStatus;

  @override
  Future<att.TrackingStatus> request() =>
      att.AppTrackingTransparency.requestTrackingAuthorization();

  @override
  Future<String> advertisingIdentifier() =>
      att.AppTrackingTransparency.getAdvertisingIdentifier();
}

/// Maps a plugin status to the neutral authorization.
TrackingAuthorization mapTrackingStatus(att.TrackingStatus status) =>
    switch (status) {
      att.TrackingStatus.notDetermined => TrackingAuthorization.notDetermined,
      att.TrackingStatus.authorized => TrackingAuthorization.authorized,
      att.TrackingStatus.denied => TrackingAuthorization.denied,
      att.TrackingStatus.restricted => TrackingAuthorization.restricted,
      att.TrackingStatus.notSupported => TrackingAuthorization.notSupported,
    };

/// [AdvertisingIdSource] backed by App Tracking Transparency.
///
/// Only iOS has an authorization flow; elsewhere the source reports
/// `notSupported` without touching the plugin.
final class AttAdvertisingIdSource implements AdvertisingIdSource {
  /// Creates a source.
  const AttAdvertisingIdSource({
    TrackingClient client = const DefaultTrackingClient(),
    bool? isIos,
  })  : _client = client,
        _isIos = isIos;

  final TrackingClient _client;
  final bool? _isIos;

  bool get _supported => _isIos ?? Platform.isIOS;

  @override
  Future<TrackingAuthorization> authorization() async {
    if (!_supported) return TrackingAuthorization.notSupported;
    return mapTrackingStatus(await _client.status());
  }

  @override
  Future<TrackingAuthorization> requestAuthorization() async {
    if (!_supported) return TrackingAuthorization.notSupported;
    return mapTrackingStatus(await _client.request());
  }

  @override
  Future<String?> advertisingId() async {
    if (!_supported) return null;
    final id = await _client.advertisingIdentifier();
    // Apple returns all zeros when tracking is not authorized.
    final zeros = RegExp(r'^[0-]+$');
    return id.isEmpty || zeros.hasMatch(id) ? null : id;
  }
}
