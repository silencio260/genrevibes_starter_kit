import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';

import 'consent_form_preview.dart';
import 'consent_provider.dart';
import 'consent_signals_reader.dart';
import 'model/consent_debug_config.dart';
import 'model/consent_signals.dart';
import 'model/consent_snapshot.dart';
import 'model/consent_state.dart';

/// Resolves consent with a bounded wait. Failure releases startup without
/// inventing a user's consent or regional status. SDKs retain their own signals.
final class ConsentGate implements StarterModule {
  /// Creates a gate over [provider].
  ///
  /// When [failOpen] is true a consent platform failure still releases waiters,
  /// allowing the app to attempt ads using the SDK's real stored signals. Set it to false when a
  /// failure must stop dependent modules from starting at all.
  ConsentGate({
    required ConsentProvider provider,
    bool failOpen = true,
    Duration timeout = const Duration(seconds: 30),
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _provider = provider,
        _failOpen = failOpen,
        _timeout = timeout,
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
  final Duration _timeout;
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
  /// Never completes with an error. Completion means the attempt ended, not
  /// that consent was granted. The snapshot and health retain the actual outcome.
  Future<ConsentSnapshot> get ready => _ready.future;

  /// Whether the consent platform permits requesting ads.
  ///
  /// Only ad loading should wait on this. Consent answers a question the ad
  /// network asks; it is not a general gate on the application, and modules
  /// that are first-party functions — analytics above all — must not be
  /// blocked behind it.
  bool get canRequestAds => _snapshot.canRequestAds;

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

    final elapsed = Stopwatch()..start();
    try {
      final providerStart = await _provider.initialize().timeout(_timeout);
      if (_disposed) return _notReady();
      if (providerStart.isFailure) {
        return _finishWithFailure(providerStart.fold(
            onSuccess: (_) => throw StateError('Expected provider failure'),
            onFailure: (e) => e));
      }
      final remaining = _timeout - elapsed.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException('Consent took too long.');
      }
      _providerChanges = _provider.snapshotChanges.listen(_onSnapshot);
      final requested = await _provider.requestConsent().timeout(remaining);
      if (_disposed) return _notReady();
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
    } on Object catch (error, stack) {
      if (_disposed) return _notReady();
      return _finishWithFailure(KitError(
          code: error is TimeoutException
              ? KitErrorCode.timeout
              : KitErrorCode.provider,
          message: 'Consent could not be resolved.',
          cause: error,
          stackTrace: stack));
    }
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
      // Keep the actual snapshot. Releasing startup is not a consent grant.
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

  /// Whether the provider can show its form for a simulated region.
  bool get supportsFormPreview => _provider is ConsentFormPreviewProvider;

  /// Shows the consent form as [debug]'s region would see it.
  ///
  /// Development only; see [ConsentFormPreviewProvider]. Fails with
  /// [KitErrorCode.unsupported] when the provider cannot.
  Future<KitResult<void>> previewConsentForm(ConsentDebugConfig debug) async {
    if (!_initialized || _disposed) return _notReady();
    if (_provider case final ConsentFormPreviewProvider preview) {
      return preview.previewConsentForm(debug);
    }
    return const KitFailure<void>(
      KitError(
        code: KitErrorCode.unsupported,
        message: 'This consent provider cannot preview its form.',
      ),
    );
  }

  /// Whether the provider can read the consent signals its platform stored.
  bool get supportsConsentSignals => _provider is ConsentSignalsReader;

  /// Reads the IAB consent signals the platform stored for ad SDKs.
  ///
  /// Works before the gate initializes: it reads storage, not the platform.
  /// Fails with [KitErrorCode.unsupported] when the provider cannot.
  Future<KitResult<ConsentSignals>> readConsentSignals() async {
    if (_provider case final ConsentSignalsReader reader) {
      return reader.readConsentSignals();
    }
    return const KitFailure<ConsentSignals>(
      KitError(
        code: KitErrorCode.unsupported,
        message: 'This consent provider cannot read stored consent signals.',
      ),
    );
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _disposed = true;
    _release(_snapshot);
    KitResult<void> result = const KitSuccess<void>(null);
    try {
      await _providerChanges?.cancel();
      _providerChanges = null;
      result = await _provider.dispose().timeout(const Duration(seconds: 5));
    } on Object catch (error, stack) {
      result = KitFailure<void>(KitError(
          code: KitErrorCode.provider,
          message: 'Consent cleanup failed.',
          cause: error,
          stackTrace: stack));
    } finally {
      _setHealth(ModuleState.disposed);
      await _healthChanges.close();
    }
    return result;
  }

  void _onSnapshot(ConsentSnapshot value) {
    if (_disposed) return;
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
        'canRequestAds': _snapshot.canRequestAds,
        'privacyOptionsRequired': _snapshot.privacyOptionsRequired,
      },
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
