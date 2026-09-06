import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';

import 'consent_provider.dart';
import 'model/consent_snapshot.dart';
import 'model/consent_state.dart';

/// Resolves consent once and lets dependent modules wait for the outcome.
///
/// Ads and analytics must not initialize before consent is settled. Applications
/// typically express that as an ad-hoc global `Completer` plus a "already
/// initialized" boolean; this module owns that sequencing instead, so the
/// ordering rule is testable and no vendor SDK is involved.
///
/// Await [ready] before starting a module that depends on consent.
final class ConsentGate implements StarterModule {
  /// Creates a gate over [provider].
  ///
  /// When [failOpen] is true a consent platform failure still releases waiters,
  /// matching the common production stance that a broken consent SDK should
  /// degrade to limited ads rather than block the app. Set it to false when a
  /// failure must stop dependent modules from starting at all.
  ConsentGate({
    required ConsentProvider provider,
    bool failOpen = true,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _provider = provider,
        _failOpen = failOpen,
        _clock = clock,
        _logger = logger,
        _snapshot = ConsentSnapshot(
          state: ConsentState.unknown,
          observedAt: clock.now(),
        ),
        _health = ModuleHealth(
          moduleId: 'consent',
          provider: provider.providerId,
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final ConsentProvider _provider;
  final bool _failOpen;
  final KitClock _clock;
  final KitLogger _logger;
  final Completer<ConsentSnapshot> _ready = Completer<ConsentSnapshot>();
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  StreamSubscription<ConsentSnapshot>? _providerChanges;
  ConsentSnapshot _snapshot;
  ModuleHealth _health;
  Future<KitResult<void>>? _initialization;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => 'consent';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  /// Most recent consent snapshot.
  ConsentSnapshot get snapshot => _snapshot;

  /// Completes once consent has been resolved.
  ///
  /// Never completes with an error, so a caller cannot deadlock on a consent
  /// platform fault. Inspect [ConsentSnapshot.allowsPersonalizedWork] on the
  /// result to decide what may start.
  Future<ConsentSnapshot> get ready => _ready.future;

  /// Whether dependent modules may initialize.
  bool get allowsPersonalizedWork => _snapshot.allowsPersonalizedWork;

  @override
  Future<KitResult<void>> initialize() {
    if (_disposed) return Future<KitResult<void>>.value(_notReady());
    if (_initialized) {
      return Future<KitResult<void>>.value(const KitSuccess<void>(null));
    }
    final active = _initialization;
    if (active != null) return active;
    final started = _initializeOnce();
    _initialization = started;
    return started.whenComplete(() => _initialization = null);
  }

  Future<KitResult<void>> _initializeOnce() async {
    _setHealth(ModuleState.initializing);

    final providerStart = await _provider.initialize();
    if (providerStart.isFailure) {
      final error = providerStart.fold(
        onSuccess: (_) => null,
        onFailure: (value) => value,
      );
      return _finishWithFailure(error!);
    }

    _providerChanges = _provider.snapshotChanges.listen(_onSnapshot);

    final requested = await _provider.requestConsent();
    return requested.fold(
      onSuccess: (value) {
        _snapshot = value;
        _initialized = true;
        _release(value);
        _setHealth(ModuleState.ready);
        return const KitSuccess<void>(null);
      },
      onFailure: _finishWithFailure,
    );
  }

  KitResult<void> _finishWithFailure(KitError error) {
    _initialized = true;
    _logger.log(
      _failOpen ? KitLogLevel.warning : KitLogLevel.error,
      'Consent resolution failed.',
      moduleId: moduleId,
      error: error,
    );
    if (_failOpen) {
      // Release waiters as "not required" so dependent modules start in a
      // limited, non-personalized mode instead of hanging forever.
      _snapshot = ConsentSnapshot(
        state: ConsentState.notRequired,
        observedAt: _clock.now(),
      );
      _release(_snapshot);
      _setHealth(ModuleState.degraded, error: error);
      return const KitSuccess<void>(null);
    }
    _release(_snapshot);
    _setHealth(ModuleState.failed, error: error);
    return KitFailure<void>(error);
  }

  /// Presents the persistent privacy-options form.
  Future<KitResult<void>> showPrivacyOptions() async {
    if (!_initialized || _disposed) return _notReady();
    return _provider.showPrivacyOptions();
  }

  /// Clears stored consent. Intended for development and QA only.
  Future<KitResult<void>> reset() async {
    if (!_initialized || _disposed) return _notReady();
    return _provider.reset();
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    final active = _initialization;
    if (active != null) await active;
    await _providerChanges?.cancel();
    _providerChanges = null;
    final result = await _provider.dispose();
    _disposed = true;
    _release(_snapshot);
    _setHealth(ModuleState.disposed);
    await _healthChanges.close();
    return result;
  }

  void _onSnapshot(ConsentSnapshot value) {
    _snapshot = value;
    if (!_disposed && _initialized) _setHealth(_health.state);
  }

  void _release(ConsentSnapshot value) {
    if (!_ready.isCompleted) _ready.complete(value);
  }

  KitFailure<void> _notReady() {
    return const KitFailure<void>(
      KitError(
        code: KitErrorCode.notInitialized,
        message: 'Consent gate has not been initialized.',
      ),
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: _provider.providerId,
      state: state,
      observedAt: _clock.now(),
      error: error,
      details: <String, Object?>{
        'consentState': _snapshot.state.name,
        'allowsPersonalizedWork': _snapshot.allowsPersonalizedWork,
        'privacyOptionsRequired': _snapshot.privacyOptionsRequired,
      },
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
