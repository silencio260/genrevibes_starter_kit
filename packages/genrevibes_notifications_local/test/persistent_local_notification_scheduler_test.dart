import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_notifications/genrevibes_notifications.dart';
import 'package:genrevibes_notifications_local/genrevibes_notifications_local.dart';

void main() {
  test('initialization is idempotent and does not request permission',
      () async {
    final client = _FakeClient();
    final scheduler = _scheduler(client);

    expect((await scheduler.initialize()).isSuccess, isTrue);
    expect((await scheduler.initialize()).isSuccess, isTrue);
    expect(client.initializeCalls, 1);
    expect(client.permissionCalls, 0);

    expect((await scheduler.requestPermission()).isSuccess, isTrue);
    expect(client.permissionCalls, 1);
  });

  test('routes interval and daily policies to persistent platform schedules',
      () async {
    final client = _FakeClient();
    final scheduler = _scheduler(client);
    await scheduler.initialize();

    await scheduler.schedule(
      LocalNotificationRequest(
        id: 1,
        content: _content,
        schedule: LocalNotificationInterval(const Duration(hours: 3)),
      ),
    );
    await scheduler.schedule(
      const LocalNotificationRequest(
        id: 2,
        content: _content,
        schedule: LocalNotificationDaily(hour: 8, minute: 15),
      ),
    );

    expect(client.intervals, <Duration>[const Duration(hours: 3)]);
    expect(client.daily, <(int, int)>[(8, 15)]);
  });

  test('forwards notification interactions and stops after disposal', () async {
    final client = _FakeClient();
    final scheduler = _scheduler(client);
    await scheduler.initialize();
    final interactions = <LocalNotificationInteraction>[];
    final subscription = scheduler.interactions.listen(interactions.add);

    client.onResponse!(
      const LocalNotificationInteraction(
        notificationId: 9,
        actionId: 'open',
        payload: '/saved',
      ),
    );
    await pumpEventQueue();
    expect(interactions.single.notificationId, 9);

    await subscription.cancel();
    await scheduler.dispose();
    expect((await scheduler.cancel(9)).isFailure, isTrue);
  });
}

const _content = LocalNotificationContent(
  title: 'Reminder',
  body: 'Open the app',
);

PersistentLocalNotificationScheduler _scheduler(_FakeClient client) =>
    PersistentLocalNotificationScheduler(
      configuration: const GenreVibesLocalNotificationsConfiguration(
        androidDefaultIcon: '@mipmap/ic_launcher',
        timeZoneName: 'Africa/Lagos',
      ),
      client: client,
    );

final class _FakeClient implements FlutterLocalNotificationsClient {
  int initializeCalls = 0;
  int permissionCalls = 0;
  final List<Duration> intervals = <Duration>[];
  final List<(int, int)> daily = <(int, int)>[];
  LocalNotificationResponseListener? onResponse;

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> initialize(
    GenreVibesLocalNotificationsConfiguration configuration,
    LocalNotificationResponseListener onResponse,
  ) async {
    initializeCalls++;
    this.onResponse = onResponse;
  }

  @override
  Future<List<int>> pendingIds() async => <int>[];

  @override
  Future<bool> requestPermission() async {
    permissionCalls++;
    return true;
  }

  @override
  Future<void> scheduleDaily(
    LocalNotificationRequest request, {
    required int hour,
    required int minute,
  }) async {
    daily.add((hour, minute));
  }

  @override
  Future<void> scheduleInterval(
    LocalNotificationRequest request,
    Duration interval,
  ) async {
    intervals.add(interval);
  }

  @override
  Future<void> scheduleOnce(
    LocalNotificationRequest request,
    DateTime at,
  ) async {}

  @override
  Future<void> show(int id, LocalNotificationContent content) async {}
}
