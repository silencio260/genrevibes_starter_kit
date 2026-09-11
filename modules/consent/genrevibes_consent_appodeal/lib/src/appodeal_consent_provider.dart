import 'dart:async';

import 'package:genrevibes_consent/genrevibes_consent.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

import 'appodeal_consent_client.dart';

/// Appodeal consent manager implementation of [ConsentProvider].
///
/// Appodeal's consent manager is built on Google's User Messaging Platform and
/// supports IAB TCF v2, the consent signal mediated networks read. It ships in
/// the Appodeal SDK, so an app that mediates through Appodeal does not need
/// `google_mobile_ads` for consent.
///
/// The SDK also requests consent on its own when it initializes. Resolving it
/// here first, through `ConsentGate`, puts the form ahead of the first ad
/// request and gives the application a snapshot and a privacy-options entry
/// point.
final class AppodealConsentProvider
    implements
        ConsentProvider,
        ConsentFormPreviewProvider,
        ConsentSignalsReader {
  /// Creates an Appodeal consent provider.
  ///
  /// [timeout] bounds the network steps only. Presenting a form waits for the
  /// user, however long they take.
  AppodealConsentProvider({
    required String appKey,
    bool tagForUnderAgeOfConsent = false,
    AppodealConsentClient client = const DefaultAppodealConsentClient(),
    Duration timeout = const Duration(seconds: 30),
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _appKey = appKey.trim(),
        _tagForUnderAgeOfConsent = tagForUnderAgeOfConsent,
        _client = client,
        _timeout = timeout,
        _clock = clock,
        _logger = logger,
        _snapshot = ConsentSnapshot(
          state: ConsentState.unknown,
          observedAt: clock.now(),
        ),
        _health = ModuleHealth(
          moduleId: 'consent.appodeal',
          provider: 'appodeal',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final String _appKey;
  final bool _tagForUnderAgeOfConsent;
  final AppodealConsentClient _client;
  final Duration _timeout;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ConsentSnapshot> _snapshotChanges =
      StreamController<ConsentSnapshot>.broadcast();
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  ConsentSnapshot _snapshot;
  ModuleHealth _health;
  Future<void> _queue = Future<void>.value();
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get providerId => 'appodeal';

  @override
  String get moduleId => 'consent.appodeal';

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
    if (_appKey.isEmpty) {
      const error = KitError(
        code: KitErrorCode.invalidConfiguration,
        message: 'An Appodeal app key is required for consent.',
      );
      _setHealth(ModuleState.failed, error: error);
      return const KitFailure<void>(error);
    }
    _initialized = true;
    _setHealth(ModuleState.ready);
    return const KitSuccess<void>(null);
  }

  /// Updates consent information and presents the form at most once.
  ///
  /// The form is shown only when the status is `required`, and never again in
  /// the same request, so dismissing it cannot put the user in a loop.
  @override
  Future<KitResult<ConsentSnapshot>> requestConsent() {
    if (!_initialized || _disposed) {
      return Future<KitResult<ConsentSnapshot>>.value(
        _notReady<ConsentSnapshot>(),
      );
    }
    return _serialized(() async {
      try {
        final refreshed = await _request();
        _publish(refreshed);
        return KitSuccess<ConsentSnapshot>(refreshed);
      } on Object catch (error, stackTrace) {
        return _failure<ConsentSnapshot>(error, stackTrace, 'request_consent');
      }
    });
  }

  Future<ConsentSnapshot> _request() async {
    AppodealConsentStatus? status;
    Object? loadError;
    try {
      status = await _client
          .load(appKey: _appKey, tagForUnderAgeOfConsent: _tagForUnderAgeOfConsent)
          .timeout(_timeout);
    } on Object catch (error) {
      loadError = error;
    }
    var privacyOptions = await _client.privacyOptions().timeout(_timeout);

    if (status == null) {
      // Loading covers two steps: updating consent information, then loading a
      // form. The privacy-options status is known only once the first has
      // succeeded, so it says which step failed. A failure after a successful
      // update means no form is offered to this user, which is what happens
      // outside regulated regions. A failure before it is a real failure.
      if (privacyOptions == AppodealPrivacyOptions.unknown) {
        throw StateError('Consent information could not be updated: $loadError');
      }
      return _snapshotOf(
        ConsentState.notRequired,
        formAvailable: false,
        privacyOptions: privacyOptions,
      );
    }

    var state = _mapStatus(status);
    if (status == AppodealConsentStatus.required) {
      await _client.show();
      // A dismissal without an error means the form was answered.
      state = ConsentState.obtained;
      privacyOptions = await _client.privacyOptions().timeout(_timeout);
    }
    return _snapshotOf(
      state,
      formAvailable: true,
      privacyOptions: privacyOptions,
    );
  }

  @override
  Future<KitResult<void>> showPrivacyOptions() {
    if (!_initialized || _disposed) {
      return Future<KitResult<void>>.value(_notReady<void>());
    }
    return _serialized(() async {
      try {
        await _client.showPrivacyOptionsForm();
        final privacyOptions =
            await _client.privacyOptions().timeout(_timeout);
        _publish(
          _snapshotOf(
            _snapshot.state,
            formAvailable: _snapshot.formAvailable,
            privacyOptions: privacyOptions,
          ),
        );
        return const KitSuccess<void>(null);
      } on Object catch (error, stackTrace) {
        return _failure<void>(error, stackTrace, 'show_privacy_options');
      }
    });
  }

  @override
  Future<KitResult<void>> reset() {
    if (!_initialized || _disposed) {
      return Future<KitResult<void>>.value(_notReady<void>());
    }
    return _serialized(() async {
      try {
        await _client.revoke();
        _publish(
          ConsentSnapshot(state: ConsentState.unknown, observedAt: _clock.now()),
        );
        return const KitSuccess<void>(null);
      } on Object catch (error, stackTrace) {
        return _failure<void>(error, stackTrace, 'reset');
      }
    });
  }

  /// Reads the IAB consent signals Google's User Messaging Platform stored,
  /// which Appodeal and every network it mediates read. Android only.
  ///
  /// A failure here is a development-tool failure, not a consent one, so it
  /// leaves the module's health alone.
  @override
  Future<KitResult<ConsentSignals>> readConsentSignals() async {
    if (_disposed) return _notReady<ConsentSignals>();
    try {
      return KitSuccess<ConsentSignals>(
        ConsentSignals(await _client.readSignals()),
      );
    } on Object catch (error, stackTrace) {
      return KitFailure<ConsentSignals>(
        KitError(
          code: KitErrorCode.provider,
          message: 'Stored consent signals could not be read: $error',
          providerCode: 'appodeal_consent_read_signals',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Shows the form as [debug]'s region would see it.
  ///
  /// Appodeal's consent manager never passes debug settings to Google's User
  /// Messaging Platform, and Appodeal and Google each place the device by its
  /// own lookup, so neither a debug setting nor a VPN reliably shows the form
  /// outside a regulated region. This calls the platform directly, with
  /// testing forced so no device identifier is needed. A failure to load a
  /// form while the EEA is simulated means no consent message is published in
  /// AdMob for the app.
  @override
  Future<KitResult<void>> previewConsentForm(ConsentDebugConfig debug) {
    if (!_initialized || _disposed) {
      return Future<KitResult<void>>.value(_notReady<void>());
    }
    return _serialized(() async {
      try {
        await _client.previewForm(
          geography: debug.geography.name,
          testDeviceIds: debug.testDeviceIds,
        );
        return const KitSuccess<void>(null);
      } on Object catch (error, stackTrace) {
        return _failure<void>(error, stackTrace, 'preview_form');
      }
    });
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

  /// The consent form's callbacks share one platform channel handler, so two
  /// operations running at once would steal each other's callbacks.
  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  ConsentSnapshot _snapshotOf(
    ConsentState state, {
    required bool formAvailable,
    required AppodealPrivacyOptions privacyOptions,
  }) {
    return ConsentSnapshot(
      state: state,
      observedAt: _clock.now(),
      formAvailable: formAvailable,
      privacyOptionsRequired: privacyOptions == AppodealPrivacyOptions.required,
      // Appodeal exposes no answer of its own. This is UMP's rule, which its
      // consent manager is built on: ads may be requested once consent is
      // obtained or not required.
      canRequestAds:
          state == ConsentState.obtained || state == ConsentState.notRequired,
    );
  }

  static ConsentState _mapStatus(AppodealConsentStatus status) =>
      switch (status) {
        AppodealConsentStatus.unknown => ConsentState.unknown,
        AppodealConsentStatus.required => ConsentState.consentRequired,
        AppodealConsentStatus.notRequired => ConsentState.notRequired,
        AppodealConsentStatus.obtained => ConsentState.obtained,
      };

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
      code: error is TimeoutException
          ? KitErrorCode.timeout
          : KitErrorCode.provider,
      message: 'Appodeal consent $providerCode failed: $error',
      providerCode: 'appodeal_consent_$providerCode',
      cause: error,
      stackTrace: stackTrace,
    );
    _logger.log(
      KitLogLevel.warning,
      'Appodeal consent operation failed.',
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
        message: 'Appodeal consent provider has not been initialized.',
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
