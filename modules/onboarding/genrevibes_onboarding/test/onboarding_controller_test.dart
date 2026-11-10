import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_onboarding/genrevibes_onboarding.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';

void main() {
  group('OnboardingController', () {
    test('a new user has not completed onboarding', () async {
      final controller = await _ready(MemoryKeyValueStore());

      expect(controller.isCompleted, isFalse);
      expect(controller.health.state, ModuleState.ready);
    });

    test('a returning user is recognized', () async {
      final store = MemoryKeyValueStore(
        initialValues: {OnboardingKeys.completed: true},
      );

      final controller = await _ready(store);

      expect(controller.isCompleted, isTrue);
    });

    test('completing persists across instances', () async {
      final store = MemoryKeyValueStore();
      final first = await _ready(store);

      await first.complete();
      final second = await _ready(store);

      expect(second.isCompleted, isTrue);
    });

    test('reset clears completion', () async {
      final store = MemoryKeyValueStore(
        initialValues: {OnboardingKeys.completed: true},
      );
      final controller = await _ready(store);

      await controller.reset();

      expect(controller.isCompleted, isFalse);
    });

    test('notifies the root gate after reset has been saved', () async {
      final store = MemoryKeyValueStore(
        initialValues: {OnboardingKeys.completed: true},
      );
      final controller = await _ready(store);
      final reset = controller.completionChanges.first;

      expect((await controller.reset()).isSuccess, isTrue);

      expect(await reset, isFalse);
      expect(store.values[OnboardingKeys.completed], isFalse);
      expect(controller.health.details['completed'], isFalse);
      await controller.dispose();
    });

    test('reset still requests replay when already incomplete', () async {
      final controller = await _ready(MemoryKeyValueStore());
      final reset = controller.completionChanges.first;

      await controller.reset();

      expect(await reset, isFalse);
      await controller.dispose();
    });

    test('failed reset keeps completion and sends no replay request', () async {
      final controller = await _ready(_FailedWriteStore());
      final changes = <bool>[];
      final subscription = controller.completionChanges.listen(changes.add);

      expect((await controller.reset()).isFailure, isTrue);
      await Future<void>.delayed(Duration.zero);

      expect(controller.isCompleted, isTrue);
      expect(changes, isEmpty);
      await subscription.cancel();
      await controller.dispose();
    });

    test('unreadable state treats the user as new rather than skipping',
        () async {
      // Showing onboarding twice is a much better failure than never showing
      // it to a genuinely new user.
      final store = MemoryKeyValueStore(
        initialValues: {OnboardingKeys.completed: 'corrupt'},
      );

      final controller = await _ready(store);

      expect(controller.isCompleted, isFalse);
      expect(controller.health.state, ModuleState.degraded);
    });

    test('rejects work before initialization', () async {
      final controller = OnboardingController(store: MemoryKeyValueStore());

      final result = await controller.complete();

      expect(
        result.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
        KitErrorCode.notInitialized,
      );
    });

    test('initialization and disposal are idempotent', () async {
      final controller = await _ready(MemoryKeyValueStore());

      expect((await controller.initialize()).isSuccess, isTrue);
      expect((await controller.dispose()).isSuccess, isTrue);
      expect((await controller.dispose()).isSuccess, isTrue);
      expect(controller.health.state, ModuleState.disposed);
    });
  });

  group('legacy key adoption', () {
    test('reset survives reopening a store with a legacy completion', () async {
      final delegate = MemoryKeyValueStore(
        initialValues: {'has_seen_onboarding': true},
      );
      KeyValueStore migratedStore() => MigratingKeyValueStore(
            delegate: delegate,
            legacyKeys: OnboardingKeys.legacyKeys,
          );
      final first = await _ready(migratedStore());
      expect(first.isCompleted, isTrue);

      await first.reset();
      final reopened = await _ready(migratedStore());

      expect(reopened.isCompleted, isFalse);
      expect(delegate.values['has_seen_onboarding'], isTrue);
      expect(delegate.values[OnboardingKeys.completed], isFalse);
      await first.dispose();
      await reopened.dispose();
    });
    test('a user who already finished onboarding does not see it again',
        () async {
      // Without migration, adopting this package re-onboards the entire
      // existing user base on the release that ships it.
      final delegate = MemoryKeyValueStore(
        initialValues: {'has_seen_onboarding': true},
      );
      final controller = await _ready(
        MigratingKeyValueStore(
          delegate: delegate,
          legacyKeys: OnboardingKeys.legacyKeys,
        ),
      );

      expect(controller.isCompleted, isTrue);
      expect(delegate.values[OnboardingKeys.completed], isTrue);
    });

    test('a genuinely new user is still onboarded', () async {
      final controller = await _ready(
        MigratingKeyValueStore(
          delegate: MemoryKeyValueStore(),
          legacyKeys: OnboardingKeys.legacyKeys,
        ),
      );

      expect(controller.isCompleted, isFalse);
    });
  });

  group('OnboardingKeys', () {
    test('the current key is namespaced and versioned', () {
      expect(OnboardingKeys.completed, 'genrevibes.onboarding.completed.v1');
    });

    test('the persisted key has a legacy mapping', () {
      expect(
        OnboardingKeys.legacyKeys[OnboardingKeys.completed],
        'has_seen_onboarding',
      );
    });
  });
}

class _FailedWriteStore implements KeyValueStore {
  @override
  Future<KitResult<bool?>> getBool(String key) async =>
      const KitSuccess<bool?>(true);

  @override
  Future<KitResult<void>> setBool(String key, bool value) async =>
      const KitFailure<void>(KitError(
        code: KitErrorCode.provider,
        message: 'Storage write failed.',
      ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<OnboardingController> _ready(KeyValueStore store) async {
  final controller = OnboardingController(store: store);
  await controller.initialize();
  return controller;
}
