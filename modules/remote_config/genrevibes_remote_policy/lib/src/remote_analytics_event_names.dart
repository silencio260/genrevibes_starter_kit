import 'package:genrevibes_analytics/genrevibes_analytics.dart';
import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';

import 'analytics_names_schema.dart';

/// Resolves event names from remote configuration.
///
/// Reads the current snapshot on every call, so a fresh activation applies to
/// the next event with no restart. Unknown names, and blank overrides, keep
/// the canonical name.
final class RemoteAnalyticsEventNames implements AnalyticsEventNames {
  /// Creates a resolver over any snapshot source.
  const RemoteAnalyticsEventNames({
    required RemoteConfigSnapshot Function() current,
  }) : _current = current;

  /// Creates a resolver over a [RemoteConfigCoordinator].
  factory RemoteAnalyticsEventNames.forCoordinator(
    RemoteConfigCoordinator coordinator,
  ) {
    return RemoteAnalyticsEventNames(current: () => coordinator.current);
  }

  final RemoteConfigSnapshot Function() _current;

  @override
  String resolve(String canonicalName) {
    final key = AnalyticsNamesSchema.keyFor(canonicalName);
    if (key == null) return canonicalName;
    final value = _current().read(key).trim();
    return value.isEmpty ? canonicalName : value;
  }
}
