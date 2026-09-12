import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:genrevibes_notifications/genrevibes_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'local_notifications_configuration.dart';

typedef LocalNotificationResponseListener = void Function(
  LocalNotificationInteraction interaction,
);

/// Injectable seam around `flutter_local_notifications`.
abstract interface class FlutterLocalNotificationsClient {
  Future<void> initialize(
    GenRevibesLocalNotificationsConfiguration configuration,
    LocalNotificationResponseListener onResponse,
  );
  Future<bool> requestPermission();
  Future<void> show(int id, LocalNotificationContent content);
  Future<void> scheduleOnce(
    LocalNotificationRequest request,
    DateTime at,
  );
  Future<void> scheduleInterval(
    LocalNotificationRequest request,
    Duration interval,
  );
  Future<void> scheduleDaily(
    LocalNotificationRequest request, {
    required int hour,
    required int minute,
  });
  Future<List<int>> pendingIds();
  Future<void> cancel(int id);
  Future<void> cancelAll();
}

/// Default platform client for `flutter_local_notifications` 19.x.
final class DefaultFlutterLocalNotificationsClient
    implements FlutterLocalNotificationsClient {
  /// Creates a default platform client.
  DefaultFlutterLocalNotificationsClient({
    FlutterLocalNotificationsPlugin? plugin,
    this.captureLaunchInteraction = true,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Disable in headless workers: launch intent belongs to the UI isolate.
  final bool captureLaunchInteraction;
  late GenRevibesLocalNotificationsConfiguration _configuration;
  late tz.Location _location;

  @override
  Future<void> initialize(
    GenRevibesLocalNotificationsConfiguration configuration,
    LocalNotificationResponseListener onResponse,
  ) async {
    _configuration = configuration;
    tz_data.initializeTimeZones();
    _location = tz.getLocation(configuration.timeZoneName);
    final initialized = await _plugin.initialize(
      InitializationSettings(
        android:
            AndroidInitializationSettings(configuration.androidDefaultIcon),
        iOS: const DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
        macOS: const DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        onResponse(_interaction(response));
      },
    );
    if (initialized == false) {
      throw StateError('Local notifications plugin did not initialize.');
    }
    if (!captureLaunchInteraction) return;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp == true && response != null) {
      onResponse(_interaction(response));
    }
  }

  // The OS returns only the payload on a tap, including cold launches. Carry
  // the content in a versioned envelope and restore the original opaque payload
  // before publishing the interaction to application navigation listeners.
  String _contentPayload(LocalNotificationContent content) => jsonEncode({
        '_genrevibes_notification': 1,
        'title': content.title,
        'body': content.body,
        'payload': content.payload,
      });

  LocalNotificationInteraction _interaction(NotificationResponse response) {
    String? title;
    String? body;
    var payload = response.payload;
    try {
      final decoded = jsonDecode(payload ?? '');
      if (decoded is Map<String, dynamic> &&
          decoded['_genrevibes_notification'] == 1 &&
          decoded['title'] is String &&
          decoded['body'] is String &&
          (decoded['payload'] == null || decoded['payload'] is String)) {
        title = decoded['title'] as String;
        body = decoded['body'] as String;
        payload = decoded['payload'] as String?;
      }
    } on FormatException {
      // Notifications posted before this version retain their original payload.
    }
    return LocalNotificationInteraction(
      notificationId: response.id,
      actionId: response.actionId,
      payload: payload,
      title: title,
      body: body,
    );
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      case TargetPlatform.iOS:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      case TargetPlatform.macOS:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                    MacOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return true;
    }
  }

  @override
  Future<void> show(int id, LocalNotificationContent content) => _plugin.show(
        id,
        content.title,
        content.body,
        _details(content),
        payload: _contentPayload(content),
      );

  @override
  Future<void> scheduleOnce(
    LocalNotificationRequest request,
    DateTime at,
  ) =>
      _plugin.zonedSchedule(
        request.id,
        request.content.title,
        request.content.body,
        tz.TZDateTime.from(at, _location),
        _details(request.content),
        androidScheduleMode: _androidScheduleMode,
        payload: _contentPayload(request.content),
      );

  @override
  Future<void> scheduleInterval(
    LocalNotificationRequest request,
    Duration interval,
  ) =>
      _plugin.periodicallyShowWithDuration(
        request.id,
        request.content.title,
        request.content.body,
        interval,
        _details(request.content),
        androidScheduleMode: _androidScheduleMode,
        payload: _contentPayload(request.content),
      );

  @override
  Future<void> scheduleDaily(
    LocalNotificationRequest request, {
    required int hour,
    required int minute,
  }) {
    final now = tz.TZDateTime.now(_location);
    var next = tz.TZDateTime(
      _location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return _plugin.zonedSchedule(
      request.id,
      request.content.title,
      request.content.body,
      next,
      _details(request.content),
      androidScheduleMode: _androidScheduleMode,
      payload: _contentPayload(request.content),
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<List<int>> pendingIds() async =>
      (await _plugin.pendingNotificationRequests())
          .map((request) => request.id)
          .toList(growable: false);

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  AndroidScheduleMode get _androidScheduleMode =>
      _configuration.androidScheduleMode ==
              GenRevibesAndroidScheduleMode.exactAllowWhileIdle
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

  NotificationDetails _details(LocalNotificationContent content) {
    final (importance, priority) = switch (content.importance) {
      LocalNotificationImportance.low => (Importance.low, Priority.low),
      LocalNotificationImportance.normal => (
          Importance.defaultImportance,
          Priority.defaultPriority
        ),
      LocalNotificationImportance.high => (Importance.high, Priority.high),
    };
    return NotificationDetails(
      android: AndroidNotificationDetails(
        content.channelId,
        content.channelName,
        channelDescription: content.channelDescription,
        importance: importance,
        priority: priority,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
    );
  }
}
