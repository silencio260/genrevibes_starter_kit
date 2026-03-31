import 'package:flutter/widgets.dart';
import 'retention_tracker.dart';
import '../utils/analytics_names.dart';
import 'analytics_service.dart';

/// User engagement levels
enum UserEngagementLevel {
  FIRST_TIME, // First session ever
  LOW, // <3 days active or <5 total opens
  MEDIUM, // 3-6 days active or 5-15 opens
  HIGH, // 7-20 days active or 15-50 opens
  POWER_USER, // 20+ days active or 50+ opens
}

/// Targeting and segmentation logic using RetentionTracker data
///
/// mirrors the functionality of the Status Saver template.
class UserTargetingManager with WidgetsBindingObserver {
  // Singleton pattern
  static final UserTargetingManager _instance =
      UserTargetingManager._internal();
  factory UserTargetingManager() => _instance;
  UserTargetingManager._internal();

  static UserTargetingManager get instance => _instance;

  final RetentionTracker _tracker = RetentionTracker.instance;
  late AnalyticsService _analytics;

  /// Initialize and start tracking
  static Future<void> startTracking(AnalyticsService analytics) async {
    _instance._analytics = analytics;

    // 1. Track App Open
    await _instance._tracker.trackAppOpen(analytics);

    // 2. Log User Segment
    await _instance.logUserSegment();

    // 3. Register lifecycle observer
    WidgetsBinding.instance.addObserver(_instance);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tracker.trackSession(_analytics);
    }
  }

  // ========== USER SEGMENTATION ==========

  bool isFirstTimeUser() => _tracker.getTotalAppOpens() == 1;
  bool isNewUser() => _tracker.getDaysSinceInstall() < 7;
  bool isReturningUser() => _tracker.getTotalAppOpens() > 1;
  bool isLoyalUser() => _tracker.getActiveDays().length >= 7;
  bool isPowerUser() {
    final activeDays = _tracker.getActiveDays().length;
    final totalOpens = _tracker.getTotalAppOpens();
    return activeDays >= 20 || totalOpens >= 50;
  }

  UserEngagementLevel getEngagementLevel() {
    if (isFirstTimeUser()) return UserEngagementLevel.FIRST_TIME;
    if (isPowerUser()) return UserEngagementLevel.POWER_USER;

    final activeDays = _tracker.getActiveDays().length;
    final totalOpens = _tracker.getTotalAppOpens();
    if (activeDays >= 7 || totalOpens >= 15) return UserEngagementLevel.HIGH;
    if (activeDays >= 3 || totalOpens >= 5) return UserEngagementLevel.MEDIUM;
    return UserEngagementLevel.LOW;
  }

  String getUserSegment() {
    if (isPowerUser()) return 'power_user';
    if (isLoyalUser()) return 'loyal';
    if (isReturningUser()) return 'returning';
    if (isFirstTimeUser()) return 'first_time';
    return 'new';
  }

  Map<String, dynamic> getUserProfile() {
    return {
      'segment': getUserSegment(),
      'engagement_level': getEngagementLevel().toString().split('.').last,
      'is_first_time': isFirstTimeUser() ? 1 : 0,
      'is_new': isNewUser() ? 1 : 0,
      'is_loyal': isLoyalUser() ? 1 : 0,
      'is_power_user': isPowerUser() ? 1 : 0,
      'days_since_install': _tracker.getDaysSinceInstall(),
      'total_opens': _tracker.getTotalAppOpens(),
    };
  }

  // ========== ANALYTICS HELPERS ==========

  Future<void> logUserSegment() async {
    final profile = getUserProfile();
    final names = AnalyticsNames.instance;

    await _analytics.logUserSegmentEvent(names.segmentUpdate, profile);

    if (isLoyalUser()) {
      await _analytics.logUserSegmentEvent(names.userIsLoyal, profile);
    }
    if (isPowerUser()) {
      await _analytics.logUserSegmentEvent(names.userIsPowerUser, profile);
    }
  }

  Future<void> logOfferShown(String offerType) async {
    final params = getUserProfile();
    final names = AnalyticsNames.instance;
    params['offer_type'] = offerType;
    await _analytics.logTargetingEvent(names.offerShown, params);
  }
}
