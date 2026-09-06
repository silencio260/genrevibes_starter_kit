import 'package:genrevibes_core/genrevibes_core.dart';

import 'remote_config_snapshot.dart';

/// Untrusted values supplied by a provider adapter after initialization/fetch.
final class RemoteConfigProviderSnapshot {
  /// Creates a provider snapshot.
  RemoteConfigProviderSnapshot({
    required Map<String, Object?> values,
    required this.origin,
    required this.observedAt,
    Map<String, RemoteConfigValueOrigin> origins =
        const <String, RemoteConfigValueOrigin>{},
  })  : values = Map<String, Object?>.unmodifiable(values),
        origins = Map<String, RemoteConfigValueOrigin>.unmodifiable(origins);

  /// Values keyed by the application's schema names.
  final Map<String, Object?> values;

  /// Whether values came from provider persistence or a network refresh.
  final RemoteConfigValueOrigin origin;

  /// Optional per-key origins when a provider can distinguish defaults from
  /// persisted or freshly fetched values.
  final Map<String, RemoteConfigValueOrigin> origins;

  /// Time the adapter observed these values.
  final DateTime observedAt;

  /// Returns the per-key origin or the snapshot-wide fallback.
  RemoteConfigValueOrigin originOf(String key) => origins[key] ?? origin;
}

/// Contract implemented by Firebase and future remote-config providers.
abstract interface class RemoteConfigProvider implements StarterModule {
  /// Stable provider identifier such as `firebase`.
  String get providerId;

  /// Values currently activated in the provider SDK.
  RemoteConfigProviderSnapshot get current;

  /// Fetches, activates, and returns the latest provider values.
  Future<KitResult<RemoteConfigProviderSnapshot>> refresh();
}
