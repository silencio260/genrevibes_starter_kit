import 'package:genrevibes_core/genrevibes_core.dart';

import 'model/analytics_event.dart';
import 'model/analytics_user.dart';

/// Contract implemented by Firebase, PostHog, Mixpanel, and future sinks.
abstract interface class AnalyticsSink implements StarterModule {
  /// Stable sink identifier such as `firebase` or `posthog`.
  String get sinkId;

  /// Enables or disables provider-side data collection.
  Future<KitResult<void>> setCollectionEnabled(bool enabled);

  /// Records [event].
  Future<KitResult<void>> track(AnalyticsEvent event);

  /// Associates future events with [user].
  Future<KitResult<void>> identify(AnalyticsUser user);

  /// Updates properties for the currently identified user.
  Future<KitResult<void>> setUserProperties(Map<String, Object?> properties);

  /// Clears the current analytics identity.
  Future<KitResult<void>> resetIdentity();

  /// Flushes buffered events when supported.
  Future<KitResult<void>> flush();
}
