import 'model/engagement_snapshot.dart';
import 'model/retention_milestone.dart';
import 'model/user_profile.dart';

/// Receives retention and segmentation events.
///
/// The tracker reports through this rather than importing a measurement
/// provider, so retention policy never depends on one.
abstract interface class EngagementObserver {
  /// An app open was recorded.
  void onAppOpened(EngagementSnapshot snapshot);

  /// A session start was recorded.
  void onSessionStarted(EngagementSnapshot snapshot);

  /// A retention milestone was reached, reported once per install.
  void onMilestone(RetentionMilestone milestone, EngagementSnapshot snapshot);

  /// The user's profile was evaluated.
  void onProfileEvaluated(UserProfile profile);
}

/// [EngagementObserver] that records nothing.
final class NoopEngagementObserver implements EngagementObserver {
  /// Creates a no-op observer.
  const NoopEngagementObserver();

  @override
  void onAppOpened(EngagementSnapshot snapshot) {}

  @override
  void onSessionStarted(EngagementSnapshot snapshot) {}

  @override
  void onMilestone(RetentionMilestone milestone, EngagementSnapshot snapshot) {}

  @override
  void onProfileEvaluated(UserProfile profile) {}
}
