import 'dart:async';

import 'package:genrevibes_consent/genrevibes_consent.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:test/test.dart';

void main() {
  group('ConsentGate', () {
    test('releases waiters once consent resolves', () async {
      final gate = ConsentGate(provider: _FakeProvider());

      await gate.initialize();

      final released = await gate.ready;
      expect(released.state, ConsentState.obtained);
      expect(gate.health.state, ModuleState.ready);
    });

    test('a waiter registered before initialization still completes', () async {
      final gate = ConsentGate(provider: _FakeProvider());
      final waiter = gate.ready;

      await gate.initialize();

      expect((await waiter).canRequestAds, isTrue);
    });

    test('notRequired permits ads', () async {
      final provider = _FakeProvider()..state = ConsentState.notRequired;
      final gate = ConsentGate(provider: provider);

      await gate.initialize();

      expect(gate.canRequestAds, isTrue);
    });

    test('a completed form the user refused does not permit ads', () async {
      // The bug this API replaced: `obtained` was read as agreement, so a user
      // who rejected every purpose was served personalized ads anyway.
      final provider = _FakeProvider()
        ..state = ConsentState.obtained
        ..canRequestAds = false;
      final gate = ConsentGate(provider: provider);

      await gate.initialize();

      expect(gate.snapshot.state, ConsentState.obtained);
      expect(gate.canRequestAds, isFalse);
    });

    test('a provider failure still releases waiters when failing open',
        () async {
      final provider = _FakeProvider()..requestError = _error;
      final gate = ConsentGate(provider: provider);

      final result = await gate.initialize();

      expect(result.isSuccess, isTrue);
      expect((await gate.ready).canRequestAds, isTrue,
          reason: 'failing open must cost personalization, not all ads');
      expect(gate.health.state, ModuleState.degraded);
    });

    test('a provider failure fails initialization when failing closed',
        () async {
      final provider = _FakeProvider()..requestError = _error;
      final gate = ConsentGate(provider: provider, failOpen: false);

      final result = await gate.initialize();

      expect(result.isFailure, isTrue);
      expect(gate.health.state, ModuleState.failed);
    });

    test('waiters never deadlock when the provider fails closed', () async {
      final provider = _FakeProvider()..requestError = _error;
      final gate = ConsentGate(provider: provider, failOpen: false);

      await gate.initialize();

      expect((await gate.ready).state, ConsentState.unknown);
    });

    test('a provider that fails to start is reported', () async {
      final provider = _FakeProvider()..initializeError = _error;
      final gate = ConsentGate(provider: provider, failOpen: false);

      expect((await gate.initialize()).isFailure, isTrue);
    });

    test('consent is requested only once across concurrent initialization',
        () async {
      final provider = _FakeProvider();
      final gate = ConsentGate(provider: provider);

      await Future.wait<KitResult<void>>(<Future<KitResult<void>>>[
        gate.initialize(),
        gate.initialize(),
        gate.initialize(),
      ]);

      expect(provider.requestCount, 1);
    });

    test('later provider changes update the snapshot', () async {
      final provider = _FakeProvider();
      final gate = ConsentGate(provider: provider);
      await gate.initialize();

      provider.emit(ConsentState.consentRequired, canRequestAds: false);
      await Future<void>.delayed(Duration.zero);

      expect(gate.snapshot.state, ConsentState.consentRequired);
      expect(gate.canRequestAds, isFalse);
    });

    test('privacy options and reset require initialization', () async {
      final gate = ConsentGate(provider: _FakeProvider());

      final options = await gate.showPrivacyOptions();

      expect(
        options.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
        KitErrorCode.notInitialized,
      );
    });

    test('privacy options delegate to the provider once ready', () async {
      final provider = _FakeProvider();
      final gate = ConsentGate(provider: provider);
      await gate.initialize();

      expect((await gate.showPrivacyOptions()).isSuccess, isTrue);
      expect(provider.privacyOptionsCount, 1);
    });

    test('disposal is idempotent and disposes the provider', () async {
      final provider = _FakeProvider();
      final gate = ConsentGate(provider: provider);
      await gate.initialize();

      expect((await gate.dispose()).isSuccess, isTrue);
      expect((await gate.dispose()).isSuccess, isTrue);
      expect(provider.disposeCount, 1);
    });
  });
}

const _error = KitError(
  code: KitErrorCode.provider,
  message: 'consent platform unavailable',
);

final class _FakeProvider implements ConsentProvider {
  ConsentState state = ConsentState.obtained;
  bool canRequestAds = true;
  KitError? initializeError;
  KitError? requestError;
  int requestCount = 0;
  int privacyOptionsCount = 0;
  int disposeCount = 0;

  final StreamController<ConsentSnapshot> _changes =
      StreamController<ConsentSnapshot>.broadcast();
  ConsentSnapshot _snapshot = ConsentSnapshot(
    state: ConsentState.unknown,
    observedAt: DateTime.utc(2026),
  );
  ModuleState _state = ModuleState.idle;

  void emit(ConsentState next, {bool? canRequestAds}) {
    _snapshot = ConsentSnapshot(
      state: next,
      observedAt: DateTime.utc(2026),
      canRequestAds: canRequestAds ?? this.canRequestAds,
    );
    _changes.add(_snapshot);
  }

  @override
  String get providerId => 'fake';

  @override
  ConsentSnapshot get snapshot => _snapshot;

  @override
  Stream<ConsentSnapshot> get snapshotChanges => _changes.stream;

  @override
  String get moduleId => 'consent.fake';

  @override
  ModuleHealth get health => ModuleHealth(
        moduleId: moduleId,
        state: _state,
        observedAt: DateTime.utc(2026),
      );

  @override
  Stream<ModuleHealth> get healthChanges => const Stream<ModuleHealth>.empty();

  @override
  Future<KitResult<void>> initialize() async {
    final error = initializeError;
    if (error != null) return KitFailure<void>(error);
    _state = ModuleState.ready;
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<ConsentSnapshot>> requestConsent() async {
    requestCount++;
    final error = requestError;
    if (error != null) return KitFailure<ConsentSnapshot>(error);
    _snapshot = ConsentSnapshot(
      state: state,
      observedAt: DateTime.utc(2026),
      canRequestAds: canRequestAds,
    );
    return KitSuccess<ConsentSnapshot>(_snapshot);
  }

  @override
  Future<KitResult<void>> showPrivacyOptions() async {
    privacyOptionsCount++;
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> reset() async => const KitSuccess<void>(null);

  @override
  Future<KitResult<void>> dispose() async {
    disposeCount++;
    _state = ModuleState.disposed;
    await _changes.close();
    return const KitSuccess<void>(null);
  }
}
