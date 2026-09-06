import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_notifications/genrevibes_notifications.dart';
import 'package:test/test.dart';

void main() {
  test('schedules hardcoded campaigns through the neutral boundary', () async {
    final scheduler = _FakeScheduler();
    final coordinator = NotificationCampaignCoordinator(
      scheduler: scheduler,
      source: StaticNotificationCampaignSource(<LocalNotificationRequest>[
        LocalNotificationRequest(
          id: 7,
          content: LocalNotificationContent(title: 'Hello', body: 'World'),
          schedule: LocalNotificationInterval(Duration(hours: 4)),
        ),
      ]),
    );

    expect((await coordinator.refresh()).isSuccess, isTrue);
    expect(scheduler.scheduled.single.id, 7);
  });

  test('rejects duplicate ids before changing the schedule', () async {
    final scheduler = _FakeScheduler();
    const request = LocalNotificationRequest(
      id: 2,
      content: LocalNotificationContent(title: 'A', body: 'B'),
      schedule: LocalNotificationDaily(hour: 9, minute: 30),
    );
    final coordinator = NotificationCampaignCoordinator(
      scheduler: scheduler,
      source: const StaticNotificationCampaignSource(<LocalNotificationRequest>[
        request,
        request,
      ]),
    );

    final result = await coordinator.refresh();
    expect(result.isFailure, isTrue);
    expect(scheduler.scheduled, isEmpty);
  });

  test('cancels removed campaigns only inside its reserved ids', () async {
    final scheduler = _FakeScheduler()
      ..pendingItems.addAll(const <PendingLocalNotification>[
        PendingLocalNotification(id: 10),
        PendingLocalNotification(id: 11),
        PendingLocalNotification(id: 99),
      ]);
    final coordinator = NotificationCampaignCoordinator(
      scheduler: scheduler,
      source: const StaticNotificationCampaignSource(
        <LocalNotificationRequest>[],
      ),
      managedIds: const <int>{10, 11},
    );

    expect((await coordinator.refresh()).isSuccess, isTrue);
    expect(scheduler.cancelled, <int>[10, 11]);
  });

  test('uses bundled campaigns when a remote source fails', () async {
    final source = FallbackNotificationCampaignSource(
      primary: _ThrowingSource(),
      fallback: const StaticNotificationCampaignSource(
        <LocalNotificationRequest>[],
      ),
    );

    expect(await source.loadCampaigns(), isEmpty);
  });
}

final class _ThrowingSource implements NotificationCampaignSource {
  @override
  Future<List<LocalNotificationRequest>> loadCampaigns() async =>
      throw StateError('offline');
}

final class _FakeScheduler implements LocalNotificationScheduler {
  final List<LocalNotificationRequest> scheduled = <LocalNotificationRequest>[];
  final List<PendingLocalNotification> pendingItems =
      <PendingLocalNotification>[];
  final List<int> cancelled = <int>[];
  final StreamController<ModuleHealth> _health =
      StreamController<ModuleHealth>.broadcast();

  @override
  Future<KitResult<void>> cancel(int id) async {
    cancelled.add(id);
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> cancelAll() async => const KitSuccess<void>(null);

  @override
  Future<KitResult<void>> dispose() async => const KitSuccess<void>(null);

  @override
  ModuleHealth get health => ModuleHealth(
        moduleId: moduleId,
        state: ModuleState.ready,
        observedAt: DateTime(2026),
      );

  @override
  Stream<ModuleHealth> get healthChanges => _health.stream;

  @override
  Stream<LocalNotificationInteraction> get interactions => const Stream.empty();

  @override
  Future<KitResult<void>> initialize() async => const KitSuccess<void>(null);

  @override
  String get moduleId => 'notifications.local.fake';

  @override
  Future<KitResult<List<PendingLocalNotification>>> pending() async =>
      KitSuccess<List<PendingLocalNotification>>(
        List<PendingLocalNotification>.unmodifiable(pendingItems),
      );

  @override
  Future<KitResult<bool>> requestPermission() async =>
      const KitSuccess<bool>(true);

  @override
  Future<KitResult<void>> schedule(LocalNotificationRequest request) async {
    scheduled.add(request);
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> show(
    int id,
    LocalNotificationContent content,
  ) async =>
      const KitSuccess<void>(null);
}
