import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';

import 'ads_policy_keys.dart';
import 'analytics_names_schema.dart';

/// Fetch settings every portfolio app uses.
abstract final class PortfolioRemoteConfigSettings {
  /// How long a single fetch may take.
  static const fetchTimeout = Duration(minutes: 1);

  /// How often a fetch is allowed in production.
  static const minimumFetchInterval = Duration(hours: 12);
}

/// Builds the schema every portfolio app shares, plus its own keys.
abstract final class PortfolioRemoteConfigSchema {
  /// Combines ads policy, optionally analytics names, and [appKeys].
  ///
  /// [includeAnalyticsNames] adds forty-two keys that exist only to rename
  /// analytics events remotely. That is worth having when a portfolio needs to
  /// realign event names across apps without a release, and is pure noise
  /// otherwise: an application that never renames its events would see forty-two
  /// keys it did not define, all sitting at their defaults, drowning the handful
  /// it actually configured. It is opt-in for that reason.
  static RemoteConfigSchema build({
    Iterable<RemoteConfigKey<Object?>> appKeys = const [],
    bool includeAnalyticsNames = false,
  }) {
    return RemoteConfigSchema(<RemoteConfigKey<Object?>>[
      ...AdsPolicyKeys.all,
      if (includeAnalyticsNames) ...AnalyticsNamesSchema.all,
      ...appKeys,
    ]);
  }
}
