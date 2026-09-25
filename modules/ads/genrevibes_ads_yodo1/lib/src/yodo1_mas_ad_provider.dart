import 'dart:async';

import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:yodo1_mas_flutter_plugin/yodo1_mas_flutter_plugin.dart';

import 'yodo1_configuration.dart';
import 'yodo1_mas_client.dart';

/// Yodo1 MAS mediation implementation of the GenRevibes ad-provider contract.
///
/// MAS is a managed waterfall: networks, bidding, banner position and test
/// devices are set in the MAS dashboard, and the SDK exposes only load, show,
/// a readiness check and per-format callbacks. That shapes this adapter, and
/// four limitations are worth knowing before designing around it.
///
/// **One inventory slot per format.** MAS has no per-unit identity: every
/// placement of the same format shares one loaded creative. Two banner
/// placements are the same banner. [AdPlacement.id] is carried into [events]
/// so the app can tell its own placements apart, and is passed to the SDK as
/// its optional placement id for reporting, but it does not create separate
/// inventory.
///
/// **Banner and native do not go through [load] and [show].** The official
/// plugin drops those ad types natively on both platforms, so this provider
/// reports them as unsupported. Use `Yodo1BannerView` and `Yodo1NativeView`
/// from this package instead: they embed the MAS views directly, which also
/// gives placement inside the app's own layout, real disposal, and the
/// revenue callback the ad-type API never exposed.
///
/// **No impression revenue for full-screen formats.** MAS reports no paid
/// callback for them through the plugin, so [events] carries no
/// [AdEventType.paid] for interstitial, rewarded or app-open. The banner and
/// native views do report revenue, through their own callbacks.
final class Yodo1MasAdProvider implements AdProvider {
  /// Creates a Yodo1 MAS provider.
  Yodo1MasAdProvider({
    required GenRevibesYodo1Configuration configuration,
    Yodo1MasClient? client,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
    bool Function()? canRequestAds,
  })  : _configuration = configuration,
        _client = client ?? DefaultYodo1MasClient(),
        _clock = clock,
        _logger = logger,
        _canRequestAds = canRequestAds,
        _health = ModuleHealth(
          moduleId: 'ads.yodo1',
          provider: 'yodo1',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  /// Formats this provider can load and show.
  ///
  /// Banner and native are deliberately absent: the plugin cannot serve them,
  /// and `Yodo1BannerView` / `Yodo1NativeView` own those formats instead.
  static const Set<AdFormat> _formats = <AdFormat>{
    AdFormat.interstitial,
    AdFormat.rewarded,
    AdFormat.appOpen,
  };

  final GenRevibesYodo1Configuration _configuration;
  final Yodo1MasClient _client;
  final KitClock _clock;
  final KitLogger _logger;

  /// Consent gate supplied by the app: false withholds every request.
  final bool Function()? _canRequestAds;

  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  final StreamController<AdEvent> _events =
      StreamController<AdEvent>.broadcast();

  /// The placement each format is currently working on, so a callback can be
  /// reported under the placement the app actually asked for.
  final Map<AdFormat, AdPlacement> _active = <AdFormat, AdPlacement>{};
  final Map<AdFormat, bool> _ready = <AdFormat, bool>{};
  final Map<AdFormat, DateTime> _lastLoadAt = <AdFormat, DateTime>{};
  final Map<AdFormat, Completer<KitResult<AdShowResult>>> _showing =
      <AdFormat, Completer<KitResult<AdShowResult>>>{};
  final Map<AdFormat, AdReward> _rewards = <AdFormat, AdReward>{};
  final Map<AdFormat, Timer> _openDeadlines = <AdFormat, Timer>{};
  final Set<AdFormat> _opened = <AdFormat>{};
  // A timed-out presentation might still open late. Do not start a second
  // full-screen ad until the SDK resolves that presentation; inline ads are
  // independent and must not be blocked by this uncertainty.
  final Set<AdFormat> _unconfirmed = <AdFormat>{};

  ModuleHealth _health;
  bool _initialized = false;
  bool _disposed = false;
  Future<KitResult<void>>? _initializing;

  @override
  String get providerId => 'yodo1';

  @override
  String get moduleId => 'ads.yodo1';

  @override
  Set<AdFormat> get supportedFormats => _formats;

  @override
  Stream<AdEvent> get events => _events.stream;

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  Future<KitResult<void>> initialize() {
    return _initializing ??=
        _initialize().whenComplete(() => _initializing = null);
  }

  Future<KitResult<void>> _initialize() async {
    if (_initialized) return const KitSuccess<void>(null);
    if (_disposed) return _notReady<void>();
    if (!_configuration.isConfigured) {
      const error = KitError(
        code: KitErrorCode.invalidConfiguration,
        message: 'Yodo1 MAS app key must not be empty.',
      );
      _setHealth(ModuleState.failed, error: error);
      return const KitFailure<void>(error);
    }
    _setHealth(ModuleState.initializing);

    final completer = Completer<bool>();
    try {
      _client.listen(
        onInterstitial: (code, message) =>
            _onEvent(AdFormat.interstitial, code, message),
        onRewarded: (code, message) =>
            _onEvent(AdFormat.rewarded, code, message),
        onAppOpen: (code, message) => _onEvent(AdFormat.appOpen, code, message),
        onBanner: (code, message) => _onEvent(AdFormat.banner, code, message),
        onNative: (code, message) => _onEvent(AdFormat.native, code, message),
      );
      // The method-channel future can hang independently of the init callback.
      // Bound both, and accept a real late success without restarting the SDK.
      unawaited(_client.initialize(_configuration, (successful) {
        if (_disposed) return;
        if (successful) {
          _initialized = true;
          _setHealth(ModuleState.ready);
        }
        if (!completer.isCompleted) completer.complete(successful);
      }).catchError((Object error, StackTrace stack) {
        if (!completer.isCompleted) completer.completeError(error, stack);
      }));
      final successful = await completer.future.timeout(
        _configuration.initializationTimeout,
      );
      if (_disposed) return _notReady<void>();
      if (!successful) {
        throw StateError('MAS initialization callback reported failure');
      }
    } on Object catch (error, stackTrace) {
      final mapped = _error('initialize', error, stackTrace);
      _setHealth(ModuleState.failed, error: mapped);
      return KitFailure<void>(mapped);
    }

    if (_disposed) return _notReady<void>();
    // The success callback already published readiness (once).
    return const KitSuccess<void>(null);
  }

  @override
  bool isReady(AdPlacement placement) {
    if (!_initialized || _disposed || _unconfirmed.isNotEmpty) return false;
    return _ready[placement.format] ?? false;
  }

  @override
  Future<KitResult<void>> load(AdPlacement placement) async {
    final unavailable = _unavailable<void>(placement);
    if (unavailable != null) return unavailable;
    if (_ready[placement.format] == true) return const KitSuccess<void>(null);
    final lastLoad = _lastLoadAt[placement.format];
    if (lastLoad != null &&
        _clock.now().difference(lastLoad) < const Duration(seconds: 30)) {
      return const KitSuccess<void>(null);
    }
    _lastLoadAt[placement.format] = _clock.now();
    _active[placement.format] = placement;
    try {
      await _client.load(_adTypeFor(placement.format));
      // Readiness is reported by callback; ask as well, because a creative
      // cached from an earlier load fires no new event.
      _ready[placement.format] =
          await _client.isLoaded(_adTypeFor(placement.format));
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      final mapped = _error('load', error, stackTrace);
      _degrade(mapped);
      return KitFailure<void>(mapped);
    }
  }

  @override
  Future<KitResult<AdShowResult>> show(AdPlacement placement) async {
    final unavailable = _unavailable<AdShowResult>(placement);
    if (unavailable != null) return unavailable;
    final format = placement.format;
    if (_unconfirmed.isNotEmpty) {
      return const KitSuccess<AdShowResult>(
          AdShowResult(status: AdShowStatus.notReady));
    }
    final bool loaded;
    try {
      loaded = await _client
          .isLoaded(_adTypeFor(format))
          .timeout(const Duration(seconds: 5));
    } on Object catch (error, stackTrace) {
      return KitFailure<AdShowResult>(_error('readiness', error, stackTrace));
    }
    if (!loaded) {
      _ready[format] = false;
      return const KitSuccess<AdShowResult>(
        AdShowResult(status: AdShowStatus.notReady),
      );
    }
    _active[format] = placement;
    _rewards.remove(format);

    // Every format here is full-screen: the creative is only really "shown"
    // once it closes, and a rewarded one pays out just before that, so the
    // result waits for the dismissal callback.
    final completer = Completer<KitResult<AdShowResult>>();
    _showing[format] = completer;
    _opened.remove(format);
    _openDeadlines.remove(format)?.cancel();
    _openDeadlines[format] = Timer(const Duration(seconds: 10), () {
      if (_showing[format] != completer || _opened.contains(format)) return;
      _logFailure('show', format, 'No opened callback within 10 seconds');
      _unconfirmed.add(format);
      _completeShow(
          format,
          const KitFailure<AdShowResult>(KitError(
            code: KitErrorCode.provider,
            message: 'MAS did not confirm that the full-screen ad opened.',
          )));
    });
    try {
      await _client
          .show(_adTypeFor(format), placementId: placement.id)
          .timeout(const Duration(seconds: 5));
    } on Object catch (error, stackTrace) {
      _showing.remove(format);
      _openDeadlines.remove(format)?.cancel();
      final mapped = _error('show', error, stackTrace);
      _logFailure('show', format, mapped.message);
      return KitFailure<AdShowResult>(mapped);
    }
    _ready[format] = false;
    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        _showing.remove(format);
        _openDeadlines.remove(format)?.cancel();
        _opened.remove(format);
        return const KitFailure<AdShowResult>(KitError(
          code: KitErrorCode.provider,
          message: 'MAS did not report full-screen ad dismissal.',
        ));
      },
    );
  }

  /// MAS holds one creative per format and offers no way to drop it, so this
  /// only forgets what this adapter knows. Banner and native views are
  /// disposed with their widgets instead.
  @override
  Future<KitResult<void>> discard(AdPlacement placement) async {
    _ready.remove(placement.format);
    _active.remove(placement.format);
    _rewards.remove(placement.format);
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _disposed = true;
    _initialized = false;
    for (final completer in _showing.values) {
      if (!completer.isCompleted) {
        completer.complete(
          const KitSuccess<AdShowResult>(
            AdShowResult(status: AdShowStatus.shown),
          ),
        );
      }
    }
    _showing.clear();
    for (final timer in _openDeadlines.values) {
      timer.cancel();
    }
    _openDeadlines.clear();
    _opened.clear();
    _unconfirmed.clear();
    _ready.clear();
    _lastLoadAt.clear();
    _active.clear();
    _rewards.clear();
    try {
      _client.stopListening();
    } on Object catch (error, stackTrace) {
      _logger.log(
        KitLogLevel.warning,
        'Yodo1 MAS listeners could not be removed.',
        moduleId: moduleId,
        error: error,
        stackTrace: stackTrace,
      );
    }
    _setHealth(ModuleState.disposed);
    await _events.close();
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  void _onEvent(AdFormat format, int code, String message) {
    if (_disposed) return;
    final placement =
        _active[format] ?? AdPlacement(id: format.name, format: format);
    switch (code) {
      case Yodo1AdEventCodes.loaded:
        _ready[format] = true;
        _emit(AdEventType.loaded, placement);
      case Yodo1AdEventCodes.failedToLoad:
        _ready[format] = false;
        _logFailure('load', format, message);
      case Yodo1AdEventCodes.opened:
        _opened.add(format);
        _openDeadlines.remove(format)?.cancel();
        _emit(AdEventType.impression, placement);
      case Yodo1AdEventCodes.failedToOpen:
        _unconfirmed.remove(format);
        _ready[format] = false;
        _logFailure('show', format, message);
        _completeShow(
          format,
          KitFailure<AdShowResult>(
            KitError(
              code: KitErrorCode.provider,
              message: 'Yodo1 MAS could not show ${format.name}: $message',
            ),
          ),
        );
      case Yodo1AdEventCodes.earned:
        // Recorded now, attached when the creative closes: MAS reports the
        // reward before the dismissal that ends the show call.
        _rewards[format] = const AdReward(type: 'yodo1_mas', amount: 1);
      case Yodo1AdEventCodes.closed:
        _unconfirmed.remove(format);
        _emit(AdEventType.dismissed, placement);
        _completeShow(
          format,
          KitSuccess<AdShowResult>(
            AdShowResult(
              status: AdShowStatus.shown,
              reward: _rewards.remove(format),
            ),
          ),
        );
    }
  }

  void _completeShow(AdFormat format, KitResult<AdShowResult> result) {
    _openDeadlines.remove(format)?.cancel();
    _opened.remove(format);
    final completer = _showing.remove(format);
    if (completer != null && !completer.isCompleted) completer.complete(result);
  }

  void _emit(AdEventType type, AdPlacement placement) {
    if (_events.isClosed) return;
    _events.add(
      AdEvent(
        type: type,
        placement: placement,
        provider: providerId,
        occurredAt: _clock.now(),
      ),
    );
  }

  void _logFailure(String operation, AdFormat format, String message) {
    _logger.log(
      KitLogLevel.warning,
      'Yodo1 MAS could not $operation ${format.name}.',
      moduleId: moduleId,
      fields: <String, Object?>{'message': message},
    );
  }

  /// Returns a failure when a request must not reach the SDK at all.
  KitResult<T>? _unavailable<T>(AdPlacement placement) {
    if (!_initialized || _disposed) return _notReady<T>();
    if (!_formats.contains(placement.format)) {
      return KitFailure<T>(
        KitError(
          code: KitErrorCode.unsupported,
          message: 'Yodo1 MAS does not support ${placement.format.name}.',
        ),
      );
    }
    if (_canRequestAds?.call() == false) {
      return KitFailure<T>(
        const KitError(
          code: KitErrorCode.unavailable,
          message: 'Ad requests are withheld until consent allows them.',
        ),
      );
    }
    return null;
  }

  static String _adTypeFor(AdFormat format) => switch (format) {
        AdFormat.interstitial => Yodo1MasFlutterPlugin.adTypeInterstitial,
        AdFormat.rewarded => Yodo1MasFlutterPlugin.adTypeRewarded,
        AdFormat.appOpen => Yodo1MasFlutterPlugin.adTypeAppOpen,
        AdFormat.banner => Yodo1MasFlutterPlugin.adTypeBanner,
        AdFormat.native => Yodo1MasFlutterPlugin.adTypeNative,
      };

  KitError _error(String operation, Object error, StackTrace stackTrace) {
    return KitError(
      code: KitErrorCode.provider,
      message: 'Yodo1 MAS $operation failed: $error',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  void _degrade(KitError error) {
    _logger.log(
      KitLogLevel.warning,
      'Yodo1 MAS request failed.',
      moduleId: moduleId,
      error: error,
    );
    _setHealth(ModuleState.degraded, error: error);
  }

  KitFailure<T> _notReady<T>() {
    return KitFailure<T>(
      const KitError(
        code: KitErrorCode.notInitialized,
        message: 'Yodo1 MAS is not initialized.',
      ),
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    if (_disposed && state != ModuleState.disposed) return;
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: providerId,
      state: state,
      observedAt: _clock.now(),
      error: error,
      details: <String, Object?>{
        for (final format in _formats) format.name: _ready[format] ?? false,
      },
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
