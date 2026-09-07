import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_permissions/genrevibes_permissions.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';

void main() {
  group('MediaPermissionPolicy', () {
    const policy = MediaPermissionPolicy();

    test('splits media permissions on Android 13 and newer', () {
      const facts =
          PlatformFacts(isAndroid: true, isIos: false, androidSdkInt: 33);

      expect(policy.mediaKindsFor(facts), <PermissionKind>[
        PermissionKind.photos,
        PermissionKind.videos,
        PermissionKind.audio,
      ]);
    });

    test('asks for legacy storage below Android 13', () {
      const facts =
          PlatformFacts(isAndroid: true, isIos: false, androidSdkInt: 29);

      expect(policy.mediaKindsFor(facts),
          <PermissionKind>[PermissionKind.storage]);
    });

    test('uses the photo library on iOS and offers no escalation', () {
      const facts = PlatformFacts(isAndroid: false, isIos: true);

      expect(
          policy.mediaKindsFor(facts), <PermissionKind>[PermissionKind.photos]);
      expect(policy.escalationFor(facts), isNull);
    });
  });

  group('PermissionRequestThrottle', () {
    const throttle = PermissionRequestThrottle(
      maxRequests: 2,
      minimumInterval: Duration(hours: 1),
    );

    test('allows the first requests immediately', () {
      expect(
        throttle.retryAt(
          previousRequests: 1,
          lastRequestedAt: DateTime(2026),
          now: DateTime(2026),
        ),
        isNull,
      );
    });

    test('waits out the interval once the budget is spent', () {
      final last = DateTime(2026, 1, 1, 12);

      expect(
        throttle.retryAt(
          previousRequests: 2,
          lastRequestedAt: last,
          now: DateTime(2026, 1, 1, 12, 30),
        ),
        DateTime(2026, 1, 1, 13),
      );
      expect(
        throttle.retryAt(
          previousRequests: 2,
          lastRequestedAt: last,
          now: DateTime(2026, 1, 1, 13, 1),
        ),
        isNull,
      );
    });
  });

  group('PermissionCoordinator', () {
    test('rejects work before initialization', () async {
      final coordinator = PermissionCoordinator(
        provider: _FakeProvider(),
        store: MemoryKeyValueStore(),
      );

      final result = await coordinator.check(const [PermissionKind.photos]);

      expect(
        result.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
        KitErrorCode.notInitialized,
      );
    });

    test('does not prompt for a permission that is already usable', () async {
      final provider = _FakeProvider(
        states: {PermissionKind.photos: PermissionState.limited},
      );
      final coordinator = await _ready(provider);

      final result = await _request(coordinator, [PermissionKind.photos]);

      expect(result.status, PermissionFlowStatus.granted);
      expect(provider.requested, isEmpty);
    });

    test('prompts, re-checks, and reports granted', () async {
      final provider = _FakeProvider(
        states: {PermissionKind.storage: PermissionState.denied},
        onRequest: {PermissionKind.storage: PermissionState.granted},
      );
      final coordinator = await _ready(provider);

      final result = await _request(coordinator, [PermissionKind.storage]);

      expect(result.status, PermissionFlowStatus.granted);
      expect(provider.requested, [PermissionKind.storage]);
    });

    test('reports needsSettings instead of prompting a permanent denial',
        () async {
      final provider = _FakeProvider(
        states: {PermissionKind.camera: PermissionState.permanentlyDenied},
      );
      final coordinator = await _ready(provider);

      final result = await _request(coordinator, [PermissionKind.camera]);

      expect(result.status, PermissionFlowStatus.needsSettings);
      expect(provider.requested, isEmpty);
    });

    test('persists request counts and throttles after the budget', () async {
      final store = MemoryKeyValueStore();
      final clock = _FixedClock(DateTime(2026, 1, 1, 9));
      final provider = _FakeProvider(
        states: {PermissionKind.notifications: PermissionState.denied},
        onRequest: {PermissionKind.notifications: PermissionState.denied},
      );
      final coordinator = PermissionCoordinator(
        provider: provider,
        store: store,
        clock: clock,
        throttle: const PermissionRequestThrottle(
          maxRequests: 2,
          minimumInterval: Duration(hours: 24),
        ),
      );
      await coordinator.initialize();

      await _request(coordinator, [PermissionKind.notifications]);
      await _request(coordinator, [PermissionKind.notifications]);
      final third = await _request(coordinator, [PermissionKind.notifications]);

      expect(
        store.values[PermissionKeys.requestCount(PermissionKind.notifications)],
        2,
      );
      expect(third.status, PermissionFlowStatus.throttled);
      expect(third.retryAt, DateTime(2026, 1, 2, 9));
      expect(provider.requested.length, 2);
    });

    test('a provider fault degrades health and reports failed', () async {
      final provider = _FakeProvider(
        states: {PermissionKind.photos: PermissionState.denied},
        failRequest: true,
      );
      final coordinator = await _ready(provider);

      final result = await _request(coordinator, [PermissionKind.photos]);

      expect(result.status, PermissionFlowStatus.failed);
      expect(coordinator.health.state, ModuleState.degraded);
    });

    test('notifies the observer of requests and outcomes', () async {
      final observer = _RecordingObserver();
      final provider = _FakeProvider(
        states: {PermissionKind.photos: PermissionState.denied},
        onRequest: {PermissionKind.photos: PermissionState.granted},
      );
      final coordinator = PermissionCoordinator(
        provider: provider,
        store: MemoryKeyValueStore(),
        observer: observer,
      );
      await coordinator.initialize();

      await _request(coordinator, [PermissionKind.photos]);

      expect(observer.requested, [PermissionKind.photos]);
      expect(observer.resolved.single.isGranted, isTrue);
    });
  });

  group('PermissionRationaleView', () {
    testWidgets('renders copy, steps, and fires the action', (tester) async {
      var granted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PermissionRationaleView(
              title: 'Allow access to photos',
              explanation: 'So saved statuses appear in your gallery.',
              steps: const <String>['Tap Allow', 'Choose all photos'],
              ctaLabel: 'Continue',
              onGrant: () => granted = true,
            ),
          ),
        ),
      );

      expect(find.text('Allow access to photos'), findsOneWidget);
      expect(find.text('Choose all photos'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.text('Continue'));

      expect(granted, isTrue);
    });

    testWidgets('disables the action while loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PermissionRationaleView(
              title: 't',
              explanation: 'e',
              ctaLabel: 'Continue',
              isLoading: true,
              onGrant: () {},
            ),
          ),
        ),
      );

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}

Future<PermissionCoordinator> _ready(_FakeProvider provider) async {
  final coordinator =
      PermissionCoordinator(provider: provider, store: MemoryKeyValueStore());
  await coordinator.initialize();
  return coordinator;
}

Future<PermissionFlowResult> _request(
  PermissionCoordinator coordinator,
  List<PermissionKind> kinds,
) async {
  final result = await coordinator.request(kinds);
  return result.fold(
    onSuccess: (v) => v,
    onFailure: (e) => throw StateError('$e'),
  );
}

final class _FixedClock implements KitClock {
  _FixedClock(this.value);
  DateTime value;
  @override
  DateTime now() => value;
}

final class _RecordingObserver implements PermissionObserver {
  final List<PermissionKind> requested = <PermissionKind>[];
  final List<PermissionFlowResult> resolved = <PermissionFlowResult>[];
  @override
  void onRequested(List<PermissionKind> kinds) => requested.addAll(kinds);
  @override
  void onResolved(PermissionFlowResult result) => resolved.add(result);
}

final class _FakeProvider implements PermissionProvider {
  _FakeProvider({
    Map<PermissionKind, PermissionState> states = const {},
    this.onRequest = const {},
    this.failRequest = false,
  }) : states = Map<PermissionKind, PermissionState>.of(states);

  final Map<PermissionKind, PermissionState> states;
  final Map<PermissionKind, PermissionState> onRequest;
  final bool failRequest;
  final List<PermissionKind> requested = <PermissionKind>[];
  ModuleState _state = ModuleState.idle;

  @override
  String get providerId => 'fake';
  @override
  String get moduleId => 'permissions.fake';
  @override
  PlatformFacts get platform =>
      const PlatformFacts(isAndroid: true, isIos: false, androidSdkInt: 33);
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
  Future<KitResult<PermissionState>> check(PermissionKind kind) async =>
      KitSuccess<PermissionState>(states[kind] ?? PermissionState.denied);

  @override
  Future<KitResult<PermissionState>> request(PermissionKind kind) async {
    if (failRequest) {
      return const KitFailure<PermissionState>(
        KitError(code: KitErrorCode.provider, message: 'plugin missing'),
      );
    }
    requested.add(kind);
    final next = onRequest[kind] ?? states[kind] ?? PermissionState.denied;
    states[kind] = next;
    return KitSuccess<PermissionState>(next);
  }

  @override
  Future<KitResult<bool>> openSettings() async => const KitSuccess<bool>(true);

  @override
  Future<KitResult<void>> dispose() async {
    _state = ModuleState.disposed;
    return const KitSuccess<void>(null);
  }
}
