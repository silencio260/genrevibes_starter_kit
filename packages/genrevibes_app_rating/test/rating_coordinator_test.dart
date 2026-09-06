import 'package:genrevibes_app_rating/genrevibes_app_rating.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';
import 'package:test/test.dart';

void main() {
  group('RatingCoordinator initialization', () {
    test('records the install date on first run', () async {
      final store = MemoryKeyValueStore();
      final clock = _FixedClock(DateTime.utc(2026, 1, 1));

      await _coordinator(store, clock).initialize();

      expect(
        store.values[RatingKeys.installedAt],
        DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
      );
    });

    test('never overwrites an existing install date', () async {
      final original = DateTime.utc(2025, 1, 1).millisecondsSinceEpoch;
      final store = MemoryKeyValueStore(
        initialValues: {RatingKeys.installedAt: original},
      );

      await _coordinator(store, _FixedClock(DateTime.utc(2026))).initialize();

      expect(store.values[RatingKeys.installedAt], original);
    });

    test('counts each app open', () async {
      final store = MemoryKeyValueStore();

      await _coordinator(store, _FixedClock(DateTime.utc(2026))).initialize();
      await _coordinator(store, _FixedClock(DateTime.utc(2026))).initialize();

      expect(store.values[RatingKeys.appOpens], 2);
    });

    test('is idempotent within one instance', () async {
      final store = MemoryKeyValueStore();
      final coordinator = _coordinator(store, _FixedClock(DateTime.utc(2026)));

      await coordinator.initialize();
      await coordinator.initialize();

      expect(store.values[RatingKeys.appOpens], 1);
      expect(coordinator.health.state, ModuleState.ready);
    });

    test('rejects work before initialization', () async {
      final coordinator = _coordinator(
        MemoryKeyValueStore(),
        _FixedClock(DateTime.utc(2026)),
      );

      final result = await coordinator.evaluate();

      expect(
        result.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
        KitErrorCode.notInitialized,
      );
    });
  });

  group('RatingCoordinator eligibility', () {
    test('allows a prompt once every threshold is met', () async {
      final coordinator = await _eligible();

      final decision = await _decide(coordinator);

      expect(decision.isAllowed, isTrue);
    });

    test('blocks while the install is too recent', () async {
      final clock = _FixedClock(DateTime.utc(2026, 1, 2));
      final store = MemoryKeyValueStore();
      await _seed(store, clock, installedDaysAgo: 1, appOpens: 10);
      final coordinator = _coordinator(store, clock);
      await coordinator.initialize();

      final decision = await _decide(coordinator);

      expect(decision.blockReason, RatingBlockReason.installTooRecent);
    });

    test('blocks until the app has been opened enough times', () async {
      final clock = _FixedClock(DateTime.utc(2026, 2, 1));
      final store = MemoryKeyValueStore();
      await _seed(store, clock, installedDaysAgo: 30, appOpens: 1);
      final coordinator = _coordinator(store, clock);
      await coordinator.initialize();

      final decision = await _decide(coordinator);

      expect(decision.blockReason, RatingBlockReason.notEnoughAppOpens);
    });

    test('blocks while a recent prompt is still inside the interval', () async {
      final clock = _FixedClock(DateTime.utc(2026, 2, 1));
      final store = MemoryKeyValueStore();
      await _seed(store, clock, installedDaysAgo: 30, appOpens: 10);
      await store.setInt(
        RatingKeys.lastPromptedAt,
        clock.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch,
      );
      final coordinator = _coordinator(store, clock);
      await coordinator.initialize();

      final decision = await _decide(coordinator);

      expect(decision.blockReason, RatingBlockReason.promptedRecently);
    });

    test('allows again once the interval has elapsed', () async {
      final clock = _FixedClock(DateTime.utc(2026, 2, 1));
      final store = MemoryKeyValueStore();
      await _seed(store, clock, installedDaysAgo: 30, appOpens: 10);
      await store.setInt(
        RatingKeys.lastPromptedAt,
        clock.now().subtract(const Duration(days: 8)).millisecondsSinceEpoch,
      );
      final coordinator = _coordinator(store, clock);
      await coordinator.initialize();

      expect((await _decide(coordinator)).isAllowed, isTrue);
    });

    test('force bypasses timing and app-open thresholds', () async {
      final clock = _FixedClock(DateTime.utc(2026, 1, 1));
      final coordinator = _coordinator(MemoryKeyValueStore(), clock);
      await coordinator.initialize();

      final decision = await _decide(coordinator, force: true);

      expect(decision.isAllowed, isTrue);
    });

    test('force never overrides an explicit opt-out', () async {
      // A user who asked not to be prompted must not be prompted by a
      // milestone trigger. This is the rule most implementations get wrong.
      final clock = _FixedClock(DateTime.utc(2026, 1, 1));
      final store = MemoryKeyValueStore(
        initialValues: {RatingKeys.optedOut: true},
      );
      final coordinator = _coordinator(store, clock);
      await coordinator.initialize();

      final decision = await _decide(coordinator, force: true);

      expect(decision.blockReason, RatingBlockReason.optedOut);
    });

    test('unreadable state blocks rather than prompting blindly', () async {
      final clock = _FixedClock(DateTime.utc(2026, 2, 1));
      final store = MemoryKeyValueStore(
        initialValues: {RatingKeys.optedOut: 'corrupt'},
      );
      final coordinator = _coordinator(store, clock);
      await coordinator.initialize();

      final decision = await _decide(coordinator);

      expect(decision.blockReason, RatingBlockReason.stateUnavailable);
    });
  });

  group('RatingCoordinator triggers', () {
    test('counts named milestones independently', () async {
      final coordinator = await _eligible();

      expect(await _trigger(coordinator, 'download'), 1);
      expect(await _trigger(coordinator, 'download'), 2);
      expect(await _trigger(coordinator, 'share'), 1);
    });
  });

  group('RatingCoordinator outcomes', () {
    test('a high rating routes to the store', () async {
      final coordinator = await _eligible();

      final followUp = await _outcome(
        coordinator,
        RatingOutcome.submitted,
        rating: 5,
      );

      expect(followUp, RatingFollowUp.storeReview);
    });

    test('a low rating routes to private feedback', () async {
      final coordinator = await _eligible();

      final followUp = await _outcome(
        coordinator,
        RatingOutcome.submitted,
        rating: 2,
      );

      expect(followUp, RatingFollowUp.feedback);
    });

    test('answering stops future prompts', () async {
      final store = MemoryKeyValueStore();
      final coordinator = await _eligible(store: store);

      await _outcome(coordinator, RatingOutcome.submitted, rating: 5);

      expect(store.values[RatingKeys.optedOut], isTrue);
      expect(
          (await _decide(coordinator)).blockReason, RatingBlockReason.optedOut);
    });

    test('never opts the user out permanently', () async {
      final store = MemoryKeyValueStore();
      final coordinator = await _eligible(store: store);

      await _outcome(coordinator, RatingOutcome.never);

      expect(store.values[RatingKeys.optedOut], isTrue);
    });

    test('maybe later defers by the snooze period, not the full interval',
        () async {
      final clock = _FixedClock(DateTime.utc(2026, 2, 1));
      final store = MemoryKeyValueStore();
      final coordinator = await _eligible(store: store, clock: clock);

      await _outcome(coordinator, RatingOutcome.maybeLater);

      // Snooze is 2 days inside a 7-day interval, so the stored timestamp is
      // back-dated 5 days: exactly 2 days remain before re-qualifying.
      final stored = store.values[RatingKeys.lastPromptedAt]! as int;
      final backdated = clock.now().difference(
            DateTime.fromMillisecondsSinceEpoch(stored),
          );
      expect(backdated, const Duration(days: 5));
      expect(store.values[RatingKeys.optedOut], isNull);
    });

    test('a snoozed user re-qualifies after exactly the snooze period',
        () async {
      final clock = _FixedClock(DateTime.utc(2026, 2, 1));
      final store = MemoryKeyValueStore();
      await _seed(store, clock, installedDaysAgo: 30, appOpens: 10);
      final coordinator = _coordinator(store, clock);
      await coordinator.initialize();
      await _outcome(coordinator, RatingOutcome.maybeLater);

      clock.value = DateTime.utc(2026, 2, 3);

      expect((await _decide(coordinator)).isAllowed, isTrue);
    });
  });

  group('RatingCoordinator presentation', () {
    test('runs the prompt through the suppression hook', () async {
      var suppressed = false;
      final coordinator = await _eligible(
        suppressionHook: (action) async {
          suppressed = true;
          await action();
        },
      );

      await coordinator.present(() async {});

      expect(suppressed, isTrue);
    });

    test('records the prompt so the interval starts', () async {
      final store = MemoryKeyValueStore();
      final coordinator = await _eligible(store: store);

      await coordinator.present(() async {});

      expect(store.values[RatingKeys.lastPromptedAt], isNotNull);
    });

    test('a throwing prompt is reported rather than propagated', () async {
      final coordinator = await _eligible();

      final result = await coordinator.present(
        () async => throw StateError('no context'),
      );

      expect(result.isFailure, isTrue);
    });

    test('notifies the observer of evaluation, prompt, and outcome', () async {
      final observer = _RecordingObserver();
      final coordinator = await _eligible(observer: observer);

      await coordinator.evaluate();
      await coordinator.present(() async {});
      await coordinator.recordOutcome(RatingOutcome.submitted, rating: 5);

      expect(observer.evaluated, 1);
      expect(observer.prompted, 1);
      expect(observer.outcomes, <RatingOutcome>[RatingOutcome.submitted]);
    });
  });

  group('legacy key adoption', () {
    test('an existing user keeps their opt-out and is not re-prompted',
        () async {
      // Without migration this user would be prompted again on the release
      // that adopts the package.
      final delegate = MemoryKeyValueStore(
        initialValues: {'never_show_rating': true},
      );
      final store = MigratingKeyValueStore(
        delegate: delegate,
        legacyKeys: RatingKeys.legacyKeys,
      );
      final coordinator = _coordinator(store, _FixedClock(DateTime.utc(2026)));
      await coordinator.initialize();

      expect(
          (await _decide(coordinator)).blockReason, RatingBlockReason.optedOut);
    });

    test('an existing install date is adopted, not reset', () async {
      final clock = _FixedClock(DateTime.utc(2026, 2, 1));
      final original =
          clock.now().subtract(const Duration(days: 90)).millisecondsSinceEpoch;
      final delegate = MemoryKeyValueStore(
        initialValues: {'app_install_date': original, 'app_opens_count': 40},
      );
      final store = MigratingKeyValueStore(
        delegate: delegate,
        legacyKeys: RatingKeys.legacyKeys,
      );
      final coordinator = _coordinator(store, clock);
      await coordinator.initialize();

      // Adopted, so the install-age threshold is already satisfied.
      expect((await _decide(coordinator)).isAllowed, isTrue);
      expect(delegate.values[RatingKeys.installedAt], original);
    });
  });
}

RatingCoordinator _coordinator(
  KeyValueStore store,
  KitClock clock, {
  RatingObserver observer = const NoopRatingObserver(),
  RatingSuppressionHook? suppressionHook,
}) {
  return RatingCoordinator(
    store: store,
    clock: clock,
    observer: observer,
    suppressionHook: suppressionHook,
  );
}

Future<RatingCoordinator> _eligible({
  MemoryKeyValueStore? store,
  _FixedClock? clock,
  RatingObserver observer = const NoopRatingObserver(),
  RatingSuppressionHook? suppressionHook,
}) async {
  final resolvedClock = clock ?? _FixedClock(DateTime.utc(2026, 2, 1));
  final resolvedStore = store ?? MemoryKeyValueStore();
  await _seed(resolvedStore, resolvedClock, installedDaysAgo: 30, appOpens: 10);
  final coordinator = _coordinator(
    resolvedStore,
    resolvedClock,
    observer: observer,
    suppressionHook: suppressionHook,
  );
  await coordinator.initialize();
  return coordinator;
}

Future<void> _seed(
  MemoryKeyValueStore store,
  KitClock clock, {
  required int installedDaysAgo,
  required int appOpens,
}) async {
  await store.setInt(
    RatingKeys.installedAt,
    clock
        .now()
        .subtract(Duration(days: installedDaysAgo))
        .millisecondsSinceEpoch,
  );
  await store.setInt(RatingKeys.appOpens, appOpens);
}

Future<RatingDecision> _decide(
  RatingCoordinator coordinator, {
  bool force = false,
}) async {
  final result = await coordinator.evaluate(force: force);
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw StateError('evaluate failed: $error'),
  );
}

Future<int> _trigger(RatingCoordinator coordinator, String name) async {
  final result = await coordinator.recordTrigger(name);
  return result.fold(
      onSuccess: (v) => v, onFailure: (e) => throw StateError('$e'));
}

Future<RatingFollowUp> _outcome(
  RatingCoordinator coordinator,
  RatingOutcome outcome, {
  int? rating,
}) async {
  final result = await coordinator.recordOutcome(outcome, rating: rating);
  return result.fold(
      onSuccess: (v) => v, onFailure: (e) => throw StateError('$e'));
}

final class _FixedClock implements KitClock {
  _FixedClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

final class _RecordingObserver implements RatingObserver {
  int evaluated = 0;
  int prompted = 0;
  final List<RatingOutcome> outcomes = <RatingOutcome>[];

  @override
  void onEvaluated(RatingDecision decision) => evaluated++;

  @override
  void onPrompted() => prompted++;

  @override
  void onOutcome(RatingOutcome outcome, {int? rating}) => outcomes.add(outcome);
}
