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
  /// Combines ads policy, analytics names and [appKeys] into one schema.
  static RemoteConfigSchema build({
    Iterable<RemoteConfigKey<Object?>> appKeys = const [],
  }) {
    return RemoteConfigSchema(<RemoteConfigKey<Object?>>[
      ...AdsPolicyKeys.all,
      ...AnalyticsNamesSchema.all,
      ...appKeys,
    ]);
  }
}
