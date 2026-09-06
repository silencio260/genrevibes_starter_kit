import 'dart:async';

import 'package:genrevibes_analytics/genrevibes_analytics.dart';

import 'engagement_events.dart';
import 'engagement_observer.dart';
import 'model/engagement_snapshot.dart';
import 'model/retention_milestone.dart';
import 'model/user_profile.dart';

/// Forwards engagement events to an [AnalyticsPipeline].
///
/// Fire-and-forget: a retention event must never stall app startup because a
/// sink is slow or offline. The pipeline already isolates sink failures.
final class AnalyticsEngagementObserver implements EngagementObserver {
  /// Creates an observer over [pipeline].
  const AnalyticsEngagementObserver(this._pipeline);

  final AnalyticsPipeline _pipeline;

  @override
  void onAppOpened(EngagementSnapshot snapshot) {
    _track(EngagementEvents.appOpened, snapshot.toProperties());
  }

  @override
  void onSessionStarted(EngagementSnapshot snapshot) {
    _track(EngagementEvents.sessionStarted, snapshot.toProperties());
  }

  @override
  void onMilestone(RetentionMilestone milestone, EngagementSnapshot snapshot) {
    final name = switch (milestone) {
      RetentionMilestone.day1 => EngagementEvents.day1Returned,
      RetentionMilestone.day3 => EngagementEvents.day3Returned,
      RetentionMilestone.day7 => EngagementEvents.day7Returned,
      RetentionMilestone.day30 => EngagementEvents.day30Returned,
    };
    _track(name, snapshot.toProperties());
  }

  @override
  void onProfileEvaluated(UserProfile profile) {
    final properties = profile.toProperties();
    _track(EngagementEvents.segmentUpdate, properties);
    if (profile.isLoyal) _track(EngagementEvents.userIsLoyal, properties);
    if (profile.isAtRisk) _track(EngagementEvents.userAtRisk, properties);
    if (profile.isChurned) _track(EngagementEvents.userChurned, properties);
    if (profile.isPowerUser) {
      _track(EngagementEvents.userIsPowerUser, properties);
    }
  }

  void _track(String name, Map<String, Object?> properties) {
    unawaited(
      _pipeline.track(AnalyticsEvent(name: name, properties: properties)),
    );
  }
}
