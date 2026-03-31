import 'package:flutter/foundation.dart';
import '../../../../core/storage/local_storage.dart';
import '../utils/analytics_names.dart';
import 'analytics_service.dart';

/// Pure analytics class for tracking user retention and engagement
///
/// mirrors the functionality of the Status Saver template.
class RetentionTracker extends ChangeNotifier {
  // Singleton pattern
  static final RetentionTracker _instance = RetentionTracker._internal();
  factory RetentionTracker() => _instance;
  RetentionTracker._internal();

  static RetentionTracker get instance => _instance;

  LocalStorage? _storage;

  // Storage keys
  static const String _firstInstallKey = 'first_install_date';
  static const String _lastOpenKey = 'last_open_date';
  static const String _totalOpensKey = 'total_app_opens';
  static const String _sessionTimestampsKey = 'session_timestamps';
  static const String _dailyOpenDatesKey = 'daily_open_dates';

  // Cache
  DateTime? _firstInstallDate;
  DateTime? _lastOpenDate;
  int? _totalAppOpens;
  List<DateTime>? _sessionTimestamps;
  List<DateTime>? _dailyOpenDates;
  bool _isInitialized = false;

  /// Initialize the tracker with storage
  void init(LocalStorage storage) {
    _storage = storage;
  }

  /// Initialize and track app open
  Future<void> trackAppOpen(AnalyticsService analytics) async {
    await _ensureInitialized();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // First time setup
    if (_firstInstallDate == null) {
      _firstInstallDate = now;
      await _saveDateTime(_firstInstallKey, now);
    }

    // Update last open
    _lastOpenDate = now;
    await _saveDateTime(_lastOpenKey, now);

    // Increment total opens
    _totalAppOpens = (_totalAppOpens ?? 0) + 1;
    await _saveInt(_totalOpensKey, _totalAppOpens!);

    // Add session timestamp
    _sessionTimestamps ??= [];
    _sessionTimestamps!.add(now);
    await _saveDateTimeList(_sessionTimestampsKey, _sessionTimestamps!);

    // Add daily open date (if not already opened today)
    _dailyOpenDates ??= [];
    if (!_dailyOpenDates!.any(
      (date) =>
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day,
    )) {
      _dailyOpenDates!.add(today);
      await _saveDateTimeList(_dailyOpenDatesKey, _dailyOpenDates!);
    }

    // Log to Analytics
    await _logRetentionAnalytics(analytics, 'retention_app_opened');

    notifyListeners();
  }

  /// Track a session (can be called multiple times per app open)
  Future<void> trackSession(AnalyticsService analytics) async {
    await _ensureInitialized();

    final now = DateTime.now();
    _sessionTimestamps ??= [];
    _sessionTimestamps!.add(now);
    await _saveDateTimeList(_sessionTimestampsKey, _sessionTimestamps!);

    // Log to Analytics
    await _logRetentionAnalytics(analytics, 'retention_session_started');

    notifyListeners();
  }

  /// Helper to log retention analytics with standard params
  Future<void> _logRetentionAnalytics(
    AnalyticsService analytics,
    String eventName,
  ) async {
    final params = getEngagementMetrics();
    final names = AnalyticsNames.instance;

    // Add retention milestones
    final daysSinceInstall = getDaysSinceInstall();
    if (daysSinceInstall >= 1 && daysSinceInstall <= 30) {
      if (hasReturnedOnDay(daysSinceInstall)) {
        params['milestone_d$daysSinceInstall'] = 1;
      }
    }

    // Add D7 retention rate
    params['d7_retention_rate'] = getD7RetentionRate();

    // Use mapped names
    String mappedName = eventName;
    if (eventName == 'retention_app_opened') mappedName = names.appOpened;
    if (eventName == 'retention_session_started')
      mappedName = names.sessionStarted;

    await analytics.logRetentionEvent(mappedName, params);

    // Check for specific milestones and log them separately
    if (eventName == 'retention_app_opened') {
      if (daysSinceInstall == 1)
        await analytics.logRetentionEvent(names.day1Returned, params);
      if (daysSinceInstall == 3)
        await analytics.logRetentionEvent(names.day3Returned, params);
      if (daysSinceInstall == 7)
        await analytics.logRetentionEvent(names.day7Returned, params);
      if (daysSinceInstall == 30)
        await analytics.logRetentionEvent(names.day30Returned, params);
    }
  }

  // ========== DATA QUERIES ==========

  int getTotalAppOpens() => _totalAppOpens ?? 0;

  int getSessionCountToday() {
    if (_sessionTimestamps == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    return _sessionTimestamps!
        .where((ts) => ts.isAfter(today) && ts.isBefore(tomorrow))
        .length;
  }

  int getDaysSinceInstall() {
    if (_firstInstallDate == null) return 0;
    return DateTime.now().difference(_firstInstallDate!).inDays;
  }

  int getDaysSinceLastOpen() {
    if (_lastOpenDate == null) return 0;
    return DateTime.now().difference(_lastOpenDate!).inDays;
  }

  List<String> getActiveDays() {
    if (_dailyOpenDates == null) return [];
    return _dailyOpenDates!
        .map(
          (d) =>
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        )
        .toList();
  }

  // ========== RETENTION METRICS ==========

  bool hasReturnedOnDay(int day) {
    if (_firstInstallDate == null || _dailyOpenDates == null) return false;
    final targetDate = DateTime(
      _firstInstallDate!.year,
      _firstInstallDate!.month,
      _firstInstallDate!.day + day,
    );
    return _dailyOpenDates!.any(
      (d) =>
          d.year == targetDate.year &&
          d.month == targetDate.month &&
          d.day == targetDate.day,
    );
  }

  double getD7RetentionRate() {
    if (_firstInstallDate == null) return 0.0;
    int activeDays = 0;
    for (int day = 1; day <= 7; day++) {
      if (hasReturnedOnDay(day)) activeDays++;
    }
    return (activeDays / 7.0) * 100.0;
  }

  Map<String, dynamic> getEngagementMetrics() {
    return {
      'total_opens': getTotalAppOpens(),
      'sessions_today': getSessionCountToday(),
      'total_sessions': _sessionTimestamps?.length ?? 0,
      'active_days_count': _dailyOpenDates?.length ?? 0,
      'days_since_install': getDaysSinceInstall(),
      'days_since_last_open': getDaysSinceLastOpen(),
    };
  }

  // ========== STORAGE HELPERS ==========

  Future<void> _ensureInitialized() async {
    if (_isInitialized || _storage == null) return;

    final firstInstallStr = await _storage!.getString(_firstInstallKey);
    _firstInstallDate =
        firstInstallStr != null ? DateTime.parse(firstInstallStr) : null;

    final lastOpenStr = await _storage!.getString(_lastOpenKey);
    _lastOpenDate = lastOpenStr != null ? DateTime.parse(lastOpenStr) : null;

    _totalAppOpens = await _storage!.getInt(_totalOpensKey);

    final sessionStrs = await _storage!.getStringList(_sessionTimestampsKey);
    _sessionTimestamps = sessionStrs?.map((s) => DateTime.parse(s)).toList();

    final dailyStrs = await _storage!.getStringList(_dailyOpenDatesKey);
    _dailyOpenDates = dailyStrs?.map((s) => DateTime.parse(s)).toList();

    _isInitialized = true;
  }

  Future<void> _saveDateTime(String key, DateTime value) async {
    await _storage?.setString(key, value.toIso8601String());
  }

  Future<void> _saveInt(String key, int value) async {
    await _storage?.setInt(key, value);
  }

  Future<void> _saveDateTimeList(String key, List<DateTime> values) async {
    final strings = values.map((dt) => dt.toIso8601String()).toList();
    await _storage?.setStringList(key, strings);
  }
}
