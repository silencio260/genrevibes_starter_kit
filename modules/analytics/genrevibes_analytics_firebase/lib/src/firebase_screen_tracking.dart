import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';

/// Screen views for Firebase Analytics.
///
/// [FirebaseAnalyticsSink] delivers events, and events are all a report needs
/// to count things. Screen views are different: Firebase records them from the
/// navigator, not from an event call, and a `screen_view` it records itself
/// also sets the screen context attached to every event that follows. Without
/// this, GA4's "Pages and screens" report is empty and DebugView shows custom
/// events with no idea where in the app they happened.
///
/// It is separate from the PostHog observer rather than a pipeline-level one on
/// purpose. PostHog already captures `$screen` from its own observer; routing
/// screen views through the pipeline as well would count every navigation twice
/// there.
///
/// Register it beside any other observers:
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: <NavigatorObserver>[
///     FirebaseScreenTracking.navigatorObserver,
///   ],
/// )
/// ```
///
/// Only page routes are tracked, so dialogs and bottom sheets do not appear as
/// screens. Collection follows the sink: when collection is disabled, Firebase
/// drops these along with everything else.
abstract final class FirebaseScreenTracking {
  /// Records a `screen_view` named after each route as it becomes current.
  ///
  /// Created once, on first access. A fresh instance per build would register
  /// duplicate observers on a rebuild, and first access happens while the app
  /// widget builds — after the host has initialized Firebase.
  static final NavigatorObserver navigatorObserver =
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);
}
