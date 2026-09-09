import 'dart:async';

import 'package:genrevibes_consent/genrevibes_consent.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

import 'ump_client.dart';
import 'ump_consent_mapping.dart';

/// Google User Messaging Platform implementation of [ConsentProvider].
///
/// UMP ships inside `google_mobile_ads`, so this adapter carries that
/// dependency and the neutral consent package does not.
final class UmpConsentProvider implements ConsentProvider {
  /// Creates a UMP consent provider.
  UmpConsentProvider({
    ConsentDebugConfig debugConfig = const ConsentDebugConfig(),
    UmpClient client = const DefaultUmpClient(),
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _debugConfig = debugConfig,
        _client = client,
        _clock = clock,
        _logger = logger,
        _snapshot = ConsentSnapshot(
          state: ConsentState.unknown,
          observedAt: clock.now(),
        ),
        _health = ModuleHealth(
          moduleId: 'consent.ump',
          provider: 'ump',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final ConsentDebugConfig _debugConfig;
  final UmpClient _client;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ConsentSnapshot> _snapshotChanges =
      StreamController<ConsentSnapshot>.broadcast();
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  ConsentSnapshot _snapshot;
  ModuleHealth _health;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get providerId => 'ump';

  @override
  String get moduleId => 'consent.ump';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  ConsentSnapshot get snapshot => _snapshot;

  @override
  Stream<ConsentSnapshot> get snapshotChanges => _snapshotChanges.stream;

  @override
  Future<KitResult<void>> initialize() async {
    if (_disposed) return _notReady<void>();
    if (_initialized) return const KitSuccess<void>(null);
    if (_debugConfig.isActive) {
      _logger.log(
        KitLogLevel.warning,
        'UMP debug settings are active. Do not ship this configuration.',
        moduleId: moduleId,
      );
    }
    _initialized = true;
    _setHealth(ModuleState.ready);
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<ConsentSnapshot>> requestConsent() async {
    if (!_initialized || _disposed) return _notReady<ConsentSnapshot>();
    try {
      await _client.requestConsentInfoUpdate(mapUmpDebugConfig(_debugConfig));
      // Presents the form only while consent is still required. The SDK helper
      // owns that check, so a dismissal cannot re-trigger presentation here.
      await _client.loadAndShowConsentFormIfRequired();
      final refreshed = await _readSnapshot();
      _publish(refreshed);
      return KitSuccess<ConsentSnapshot>(refreshed);
    } on Object catch (error, stackTrace) {
      return _failure<ConsentSnapshot>(error, stackTrace, 'request_consent');
    }
  }

  @override
  Future<KitResult<void>> showPrivacyOptions() async {
    if (!_initialized || _disposed) return _notReady<void>();
    try {
      await _client.showPrivacyOptionsForm();
      _publish(await _readSnapshot());
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      return _failure<void>(error, stackTrace, 'show_privacy_options');
    }
  }

  @override
  Future<KitResult<void>> reset() async {
    if (!_initialized || _disposed) return _notReady<void>();
    try {
      await _client.reset();
      _publish(
        ConsentSnapshot(
          state: ConsentState.unknown,
          observedAt: _clock.now(),
        ),
      );
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      return _failure<void>(error, stackTrace, 'reset');
    }
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _disposed = true;
    _setHealth(ModuleState.disposed);
    await _snapshotChanges.close();
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  Future<ConsentSnapshot> _readSnapshot() async {
    final status = await _client.getConsentStatus();
    final privacyOptions = await _client.getPrivacyOptionsRequirementStatus();
    final formAvailable = await _client.isConsentFormAvailable();
    // Asked of the SDK rather than derived from `status`, because the two are
    // not the same question and the SDK is the only thing that knows.
    final canRequestAds = await _client.canRequestAds();
    return ConsentSnapshot(
      state: mapUmpConsentStatus(status),
      observedAt: _clock.now(),
      formAvailable: formAvailable,
      privacyOptionsRequired: mapUmpPrivacyOptionsRequired(privacyOptions),
      canRequestAds: canRequestAds,
    );
  }

  void _publish(ConsentSnapshot value) {
    _snapshot = value;
    if (!_snapshotChanges.isClosed) _snapshotChanges.add(value);
    if (!_disposed) _setHealth(ModuleState.ready);
  }

  KitFailure<T> _failure<T>(
    Object error,
    StackTrace stackTrace,
    String providerCode,
  ) {
    final mapped = KitError(
      code: KitErrorCode.provider,
      message: 'UMP $providerCode failed: $error',
      providerCode: 'ump_$providerCode',
      cause: error,
      stackTrace: stackTrace,
    );
    _logger.log(
      KitLogLevel.warning,
      'UMP consent operation failed.',
      moduleId: moduleId,
      error: mapped,
    );
    if (!_disposed) _setHealth(ModuleState.degraded, error: mapped);
    return KitFailure<T>(mapped);
  }

  KitFailure<T> _notReady<T>() {
    return KitFailure<T>(
      const KitError(
        code: KitErrorCode.notInitialized,
        message: 'UMP consent provider has not been initialized.',
      ),
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: providerId,
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
