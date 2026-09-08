import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Screen tracking and session replay for PostHog.
///
/// [PostHogAnalyticsSink] delivers events, which is all an application needs to
/// count things. Screen views and session replay are different: PostHog
/// captures them from the widget tree rather than from an event call, so they
/// require a widget and a navigator observer that only this package can supply.
///
/// Without this, an application adopting the sink would still have to depend on
/// `posthog_flutter` directly to keep the screen tracking it already had, which
/// leaves a vendor SDK in its dependency list for the sake of two lines.
///
/// Wrap the application and register the observer:
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: <NavigatorObserver>[PostHogScope.navigatorObserver],
///   builder: (context, child) => PostHogScope(child: child!),
/// )
/// ```
///
/// Both are inert until the SDK is configured, so ordering against
/// [PostHogAnalyticsSink] initialization does not matter.
final class PostHogScope extends StatelessWidget {
  /// Wraps [child] so PostHog can capture session replay from it.
  const PostHogScope({required this.child, super.key});

  /// The subtree to capture.
  final Widget child;

  /// Records a screen view for each route push and pop.
  ///
  /// A fresh instance per call would register duplicate observers on a rebuild,
  /// so this is created once.
  static final NavigatorObserver navigatorObserver = PosthogObserver();

  @override
  Widget build(BuildContext context) => PostHogWidget(child: child);
}
