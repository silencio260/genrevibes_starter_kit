import 'package:genrevibes_analytics/genrevibes_analytics.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_engagement/genrevibes_engagement.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';
import 'package:test/test.dart';

void main() {
  group('RetentionTracker opens and sessions', () {
    test('records the install date once and counts opens', () async {
      final store = MemoryKeyValueStore();
      final clock = _FixedClock(DateTime(2026, 1, 1, 9));
      final tracker = await _ready(store, clock);

      await tracker.recordAppOpen();
      clock.value = DateTime(2026, 1, 1, 18);
      await tracker.recordAppOpen();

      expect(store.values[EngagementKeys.installedAt],
          DateTime(2026, 1, 1, 9).toIso8601String());
      expect(store.values[EngagementKeys.totalOpens], 2);
      expect(tracker.snapshot.activeDays, 1, reason: 'same day dedupes');
    });

    test('a second instance keeps the original install date', () async {
      final store = MemoryKeyValueStore();
      final first = await _ready(store, _FixedClock(DateTime(2026, 1, 1)));
      await first.recordAppOpen();

      final second = await _ready(store, _FixedClock(DateTime(2026, 3, 1)));
      await second.recordAppOpen();

      expect(second.snapshot.installedAt, DateTime(2026, 1, 1));
      expect(second.snapshot.daysSinceInstall, 59);
    });

    test('sessions today counts only today', () async {
      final store = MemoryKeyValueStore();
      final clock = _FixedClock(DateTime(2026, 1, 1, 8));
      final tracker = await _ready(store, clock);
      await tracker.recordAppOpen();
      await tracker.recordSession();
      clock.value = DateTime(2026, 1, 2, 8);
      await tracker.recordSession();

      expect(tracker.snapshot.sessionsToday, 1);
    });

    test('session history is capped', () async {
      final store = MemoryKeyValueStore();
      final tracker = RetentionTracker(
        store: store,
        clock: _FixedClock(DateTime(2026)),
        sessionHistoryLimit: 3,
      );
      await tracker.initialize();

      for (var i = 0; i < 5; i++) {
        await tracker.recordSession();
      }

      expect(
        (store.values[EngagementKeys.sessionTimestamps]! as List<String>)
            .length,
        3,
      );
    });

    test('rejects work before initialization', () async {
      final tracker = RetentionTracker(store: MemoryKeyValueStore());

      final result = await tracker.recordAppOpen();

      expect(
        result.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
        KitErrorCode.notInitialized,
      );
    });

    test('unreadable history starts fresh and degrades health', () async {
      final store = MemoryKeyValueStore(
        initialValues: {EngagementKeys.totalOpens: 'corrupt'},
      );

      final tracker = await _ready(store, _FixedClock(DateTime(2026)));

      expect(tracker.health.state, ModuleState.degraded);
      expect(tracker.snapshot.totalOpens, 0);
    });
  });

  group('RetentionTracker milestones', () {
    test('reports day 1 once, not on every open that day', () async {
      final store = MemoryKeyValueStore();
      final observer = _RecordingObserver();
      final clock = _FixedClock(DateTime(2026, 1, 1));
      final tracker = await _ready(store, clock, observer: observer);
      await tracker.recordAppOpen();

      clock.value = DateTime(2026, 1, 2, 9);
      await tracker.recordAppOpen();
      clock.value = DateTime(2026, 1, 2, 20);
      await tracker.recordAppOpen();

      expect(
          observer.milestones, <RetentionMilestone>[RetentionMilestone.day1]);
    });

    test('day 30 fires, unlike trackers capped at a week', () async {
      final store = MemoryKeyValueStore();
      final observer = _RecordingObserver();
      final clock = _FixedClock(DateTime(2026, 1, 1));
      final tracker = await _ready(store, clock, observer: observer);
      await tracker.recordAppOpen();

      clock.value = DateTime(2026, 1, 31);
      await tracker.recordAppOpen();

      expect(observer.milestones, contains(RetentionMilestone.day30));
    });

    test('a non-milestone day reports nothing', () async {
      final observer = _RecordingObserver();
      final clock = _FixedClock(DateTime(2026, 1, 1));
      final tracker =
          await _ready(MemoryKeyValueStore(), clock, observer: observer);
      await tracker.recordAppOpen();

      clock.value = DateTime(2026, 1, 3);
      await tracker.recordAppOpen();

      expect(observer.milestones, isEmpty);
    });
  });

  group('EngagementSnapshot retention math', () {
    test('D7 rate counts days 1..7 after install', () {
      final install = DateTime(2026, 1, 1);
      final snapshot = EngagementSnapshot.compute(
        now: DateTime(2026, 1, 10),
        installedAt: install,
        lastOpenedAt: DateTime(2026, 1, 10),
        totalOpens: 4,
        sessionTimestamps: const <DateTime>[],
        activeDates: <DateTime>[
          install,
          DateTime(2026, 1, 2),
          DateTime(2026, 1, 4),
          DateTime(2026, 1, 8),
          DateTime(2026, 1, 10),
        ],
      );

      expect(snapshot.returnedOnDay(1), isTrue);
      expect(snapshot.returnedOnDay(3), isTrue);
      expect(snapshot.returnedOnDay(7), isTrue);
      expect(snapshot.returnedOnDay(2), isFalse);
      expect(snapshot.d7RetentionRate, closeTo(3 / 7 * 100, 0.001));
      expect(snapshot.weeklyRetentionRate, 50);
    });

    test('rates are zero before install', () {
      final snapshot = EngagementSnapshot.compute(
        now: DateTime(2026),
        installedAt: null,
        lastOpenedAt: null,
        totalOpens: 0,
        sessionTimestamps: const <DateTime>[],
        activeDates: const <DateTime>[],
      );

      expect(snapshot.d7RetentionRate, 0);
      expect(snapshot.daysSinceInstall, 0);
    });
  });

  group('UserTargetingPolicy', () {
    const policy = UserTargetingPolicy();

    test('first session is first time at every layer', () {
      final p = policy.profile(_snap(opens: 1, activeDays: 1, days: 0));

      expect(p.segment, UserSegment.firstTime);
      expect(p.level, EngagementLevel.firstTime);
      expect(p.decisions.welcomeOffer, isTrue);
    });

    test('segment precedence favors power over loyal over churned', () {
      expect(
        policy.profile(_snap(opens: 60, activeDays: 25, days: 40)).segment,
        UserSegment.powerUser,
      );
      expect(
        policy
            .profile(_snap(opens: 10, activeDays: 8, days: 20, sinceOpen: 10))
            .segment,
        UserSegment.loyal,
        reason: 'loyal outranks churned',
      );
      expect(
        policy
            .profile(_snap(opens: 4, activeDays: 2, days: 20, sinceOpen: 8))
            .segment,
        UserSegment.churned,
      );
      expect(
        policy
            .profile(_snap(opens: 4, activeDays: 2, days: 20, sinceOpen: 4))
            .segment,
        UserSegment.atRisk,
      );
      expect(
        policy.profile(_snap(opens: 2, activeDays: 2, days: 1)).segment,
        UserSegment.returning,
      );
    });

    test('engagement level bands', () {
      expect(policy.profile(_snap(opens: 2, activeDays: 1, days: 1)).level,
          EngagementLevel.low);
      expect(policy.profile(_snap(opens: 5, activeDays: 1, days: 1)).level,
          EngagementLevel.medium);
      expect(policy.profile(_snap(opens: 15, activeDays: 1, days: 1)).level,
          EngagementLevel.high);
      expect(policy.profile(_snap(opens: 50, activeDays: 1, days: 1)).level,
          EngagementLevel.powerUser);
    });

    test('engagement score follows the weighted formula', () {
      // 10 active days -> 20; 20 opens -> 10; d7 0 -> 0; opened today -> 10.
      final p = policy.profile(_snap(opens: 20, activeDays: 10, days: 30));

      expect(p.score, 40);
    });

    test('rating prompt is timely on days 3..7 with three active days', () {
      expect(
          policy
              .profile(_snap(opens: 5, activeDays: 3, days: 3))
              .decisions
              .ratingPrompt,
          isTrue);
      expect(
          policy
              .profile(_snap(opens: 5, activeDays: 2, days: 3))
              .decisions
              .ratingPrompt,
          isFalse);
      expect(
          policy
              .profile(_snap(opens: 5, activeDays: 3, days: 8))
              .decisions
              .ratingPrompt,
          isFalse);
    });

    test('notification request is timely on day two after three opens', () {
      expect(
          policy
              .profile(_snap(opens: 3, activeDays: 2, days: 2))
              .decisions
              .notificationRequest,
          isTrue);
      expect(
          policy
              .profile(_snap(opens: 2, activeDays: 2, days: 2))
              .decisions
              .notificationRequest,
          isFalse);
    });

    test('profile properties carry the portfolio payload', () {
      final props = policy
          .profile(_snap(opens: 10, activeDays: 8, days: 20))
          .toProperties();

      expect(props['segment'], 'loyal');
      expect(props['engagement_level'], 'high');
      expect(props['is_loyal'], isTrue);
      expect(props['days_since_install'], 20);
    });
  });

  group('AnalyticsEngagementObserver', () {
    test('emits canonical events through the pipeline', () async {
      final sink = _RecordingSink();
      final pipeline = AnalyticsPipeline(
        sinks: <AnalyticsSink>[sink],
        initialConsent: AnalyticsConsent.granted,
      );
      await pipeline.initialize();
      final tracker = RetentionTracker(
        store: MemoryKeyValueStore(),
        clock: _FixedClock(DateTime(2026, 1, 1)),
        observer: AnalyticsEngagementObserver(pipeline),
      );
      await tracker.initialize();

      await tracker.recordAppOpen();
      await Future<void>.delayed(Duration.zero);

      expect(
        sink.names,
        <String>[EngagementEvents.appOpened, EngagementEvents.segmentUpdate],
      );
    });
  });

  group('legacy key adoption', () {
    test('an existing install keeps its history, lists included', () async {
      final delegate = MemoryKeyValueStore(
        initialValues: {
          'first_install_date': DateTime(2025, 12, 1).toIso8601String(),
          'last_open_date': DateTime(2025, 12, 31).toIso8601String(),
          'total_app_opens': 40,
          'session_timestamps': <String>[
            DateTime(2025, 12, 31, 9).toIso8601String(),
          ],
          'daily_open_dates': <String>[
            for (var d = 1; d <= 8; d++)
              DateTime(2025, 12, d).toIso8601String(),
          ],
        },
      );
      final store = MigratingKeyValueStore(
        delegate: delegate,
        legacyKeys: EngagementKeys.legacyKeys,
      );

      final tracker = await _ready(store, _FixedClock(DateTime(2026, 1, 1)));

      expect(tracker.snapshot.totalOpens, 40);
      expect(tracker.snapshot.activeDays, 8);
      expect(tracker.snapshot.daysSinceInstall, 31);
      expect(tracker.profile.segment, UserSegment.loyal);
    });

    test('every persisted key has a legacy mapping', () {
      expect(EngagementKeys.legacyKeys.keys.toSet(), <String>{
        EngagementKeys.installedAt,
        EngagementKeys.lastOpenedAt,
        EngagementKeys.totalOpens,
        EngagementKeys.sessionTimestamps,
        EngagementKeys.dailyOpenDates,
      });
    });
  });
}

Future<RetentionTracker> _ready(
  KeyValueStore store,
  KitClock clock, {
  EngagementObserver observer = const NoopEngagementObserver(),
}) async {
  final tracker =
      RetentionTracker(store: store, clock: clock, observer: observer);
  await tracker.initialize();
  return tracker;
}

EngagementSnapshot _snap({
  required int opens,
  required int activeDays,
  required int days,
  int sinceOpen = 0,
}) {
  final now = DateTime(2026, 6, 1);
  final install = now.subtract(Duration(days: days));
  return EngagementSnapshot.compute(
    now: now,
    installedAt: install,
    lastOpenedAt: now.subtract(Duration(days: sinceOpen)),
    totalOpens: opens,
    sessionTimestamps: const <DateTime>[],
    activeDates: <DateTime>[
      for (var i = 0; i < activeDays; i++)
        DateTime(2000, 1, 1).add(Duration(days: i)), // outside the D7 window
    ],
  );
}

final class _FixedClock implements KitClock {
  _FixedClock(this.value);
  DateTime value;
  @override
  DateTime now() => value;
}

final class _RecordingObserver implements EngagementObserver {
  final List<RetentionMilestone> milestones = <RetentionMilestone>[];
  @override
  void onAppOpened(EngagementSnapshot snapshot) {}
  @override
  void onSessionStarted(EngagementSnapshot snapshot) {}
  @override
  void onMilestone(RetentionMilestone milestone, EngagementSnapshot snapshot) =>
      milestones.add(milestone);
  @override
  void onProfileEvaluated(UserProfile profile) {}
}

final class _RecordingSink implements AnalyticsSink {
  final List<String> names = <String>[];
  ModuleState _state = ModuleState.idle;
  @override
  String get sinkId => 'recording';
  @override
  String get moduleId => 'analytics.recording';
  @override
  ModuleHealth get health => ModuleHealth(
      moduleId: moduleId, state: _state, observedAt: DateTime(2026));
  @override
  Stream<ModuleHealth> get healthChanges => const Stream<ModuleHealth>.empty();
  @override
  Future<KitResult<void>> initialize() async {
    _state = ModuleState.ready;
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> setCollectionEnabled(bool enabled) async =>
      const KitSuccess<void>(null);
  @override
  Future<KitResult<void>> track(AnalyticsEvent event) async {
    names.add(event.name);
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> identify(AnalyticsUser user) async =>
      const KitSuccess<void>(null);
  @override
  Future<KitResult<void>> setUserProperties(
          Map<String, Object?> properties) async =>
      const KitSuccess<void>(null);
  @override
  Future<KitResult<void>> resetIdentity() async => const KitSuccess<void>(null);
  @override
  Future<KitResult<void>> flush() async => const KitSuccess<void>(null);
  @override
  Future<KitResult<void>> dispose() async {
    _state = ModuleState.disposed;
    return const KitSuccess<void>(null);
  }
}
