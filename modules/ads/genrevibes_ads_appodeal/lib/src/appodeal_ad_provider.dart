import 'dart:async';

import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

import 'appodeal_client.dart';
import 'appodeal_configuration.dart';

/// Appodeal mediation implementation of the GenRevibes ad-provider contract.
///
/// Serves interstitial and rewarded placements through [load] and [show], and
/// banner placements through `AppodealBannerView`. Callbacks and revenue from
/// every mediated network arrive on [events] under the logical placement.
///
/// ## Test mode is chosen at initialization
///
/// Appodeal documents test mode as something set before the SDK initializes,
/// and documents no way to change it afterwards. [setTestMode] before
/// [initialize] picks the mode the SDK starts in. A change after
/// initialization cannot be relied on to reach the SDK, so the provider
/// withholds all inventory instead — nothing loads, nothing shows, and the
/// banner view renders nothing — until the app is relaunched and starts in the
/// new mode. A phone recognised as a developer device mid-session sees no ads
/// rather than a live one.
final class AppodealAdProvider implements AdProvider, AdTestModeProvider {
  /// Creates an Appodeal provider.
  ///
  /// [testMode] is the mode to start in; see the class documentation for
  /// changing it later.
  AppodealAdProvider({
    required GenRevibesAppodealConfiguration configuration,
    AppodealClient? client,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
    bool testMode = false,
  })  : _configuration = configuration,
        _client = client ?? DefaultAppodealClient(),
        _clock = clock,
        _logger = logger,
        _testMode = testMode,
        _health = ModuleHealth(
          moduleId: 'ads.appodeal',
          provider: 'appodeal',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  static const Set<AdFormat> _formats = <AdFormat>{
    AdFormat.interstitial,
    AdFormat.rewarded,
    AdFormat.banner,
  };

  static const Set<AdFormat> _fullScreen = <AdFormat>{
    AdFormat.interstitial,
    AdFormat.rewarded,
  };

  final GenRevibesAppodealConfiguration _configuration;
  final AppodealClient _client;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<AdEvent> _events =
      StreamController<AdEvent>.broadcast();
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();

  final Map<AdFormat, bool> _ready = <AdFormat, bool>{};
  final Map<AdFormat, Future<void>> _pendingLoads = <AdFormat, Future<void>>{};
  final Map<AdFormat, Completer<void>> _loadCompleters =
      <AdFormat, Completer<void>>{};
  final Set<AdFormat> _discardedDuringLoad = <AdFormat>{};
  final Map<AdFormat, Completer<AdShowResult>> _showCompleters =
      <AdFormat, Completer<AdShowResult>>{};
  final Map<AdFormat, AdPlacement> _showing = <AdFormat, AdPlacement>{};
  final Map<AdFormat, AdReward?> _rewards = <AdFormat, AdReward?>{};

  StreamSubscription<AppodealCallback>? _callbackSubscription;
  StreamSubscription<AppodealRevenueReport>? _revenueSubscription;
  Future<KitResult<void>>? _initialization;
  ModuleHealth _health;
  List<String> _initializationWarnings = const <String>[];
  bool _testMode;
  bool? _sdkTestMode;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => 'ads.appodeal';

  @override
  String get providerId => 'appodeal';

  @override
  Set<AdFormat> get supportedFormats => _formats;

  @override
  Stream<AdEvent> get events => _events.stream;

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  /// The mode requested most recently.
  ///
  /// Not necessarily the mode the SDK is running in; see [servesInventory].
  @override
  bool get isTestMode => _testMode;

  /// Whether inventory is served at all right now.
  ///
  /// False before initialization, after disposal, and after a test-mode change
  /// that waits for a relaunch.
  bool get servesInventory =>
      _initialized && !_disposed && _sdkTestMode == _testMode;

  /// Whether an inline banner for [placement] may be rendered now.
  bool canShowInline(AdPlacement placement) =>
      placement.format == AdFormat.banner &&
      _configuration.placementFor(placement) != null &&
      servesInventory;

  /// The Appodeal placement name [placement] is shown under, if configured.
  String? placementNameFor(AdPlacement placement) =>
      _configuration.placementFor(placement)?.name;

  @override
  Future<KitResult<void>> initialize() {
    if (_initialized) {
      return Future<KitResult<void>>.value(const KitSuccess<void>(null));
    }
    if (_disposed) return Future<KitResult<void>>.value(_notReady<void>());
    final active = _initialization;
    if (active != null) return active;
    final started = _initializeOnce();
    _initialization = started;
    return started.whenComplete(() => _initialization = null);
  }

  Future<KitResult<void>> _initializeOnce() async {
    final invalid = _validateConfiguration();
    if (invalid != null) {
      _setHealth(ModuleState.failed, error: invalid);
      return KitFailure<void>(invalid);
    }
    _setHealth(ModuleState.initializing);
    _callbackSubscription ??= _client.callbacks.listen(_onCallback);
    _revenueSubscription ??= _client.revenue.listen(_onRevenue);

    final testMode = _testMode;
    try {
      final errors = await _client
          .initialize(
            appKey: _configuration.appKey.trim(),
            formats: _configuration.formats,
            testMode: testMode,
            verboseLogging: _configuration.verboseLogging,
            childDirectedTreatment: _configuration.childDirectedTreatment,
          )
          .timeout(_configuration.initializationTimeout);
      if (_disposed) return _notReady<void>();

      final critical = errors.where(_isCritical).toList(growable: false);
      final started = critical.isEmpty && await _anyFormatInitialized();
      if (_disposed) return _notReady<void>();
      if (!started) {
        final reported = critical.isEmpty ? errors : critical;
        final error = KitError(
          code: KitErrorCode.provider,
          message: reported.isEmpty
              ? 'Appodeal initialized no ad type.'
              : 'Appodeal failed to initialize: ${reported.join('; ')}',
          providerCode: 'appodeal_initialize',
        );
        _logger.log(
          KitLogLevel.error,
          'Appodeal failed to initialize.',
          moduleId: moduleId,
          error: error,
        );
        _setHealth(ModuleState.failed, error: error);
        return KitFailure<void>(error);
      }

      // The ad types started, so the remaining errors are normal: a network
      // whose adapter is not in the build reports a non-critical one, and an
      // app with no analytics services configured in the dashboard reports
      // `InternalError: SdkConfigurationError`. They are kept in health for the
      // Starter Kit Lab rather than failing the module.
      _initializationWarnings = List<String>.unmodifiable(errors);
      if (errors.isNotEmpty) {
        _logger.log(
          KitLogLevel.info,
          'Appodeal initialized with ${errors.length} non-critical '
          'error(s): ${errors.join('; ')}',
          moduleId: moduleId,
        );
      }
      _sdkTestMode = testMode;
      _initialized = true;
      _setHealth(ModuleState.ready);
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      final failure = _mapError(error, stackTrace);
      _setHealth(ModuleState.failed, error: failure);
      return KitFailure<void>(failure);
    }
  }

  @override
  Future<KitResult<void>> load(AdPlacement placement) async {
    if (_configuration.placementFor(placement) == null) {
      return _unknownPlacement<void>(placement);
    }
    if (!_fullScreen.contains(placement.format)) {
      return _inlineOnly<void>(placement);
    }
    if (!_initialized || _disposed) return _notReady<void>();
    // Nothing is requested in a mode the SDK is not running in.
    if (!servesInventory) return const KitSuccess<void>(null);
    if (_ready[placement.format] == true) return const KitSuccess<void>(null);
    return _guard(() => _load(placement.format));
  }

  Future<void> _load(AdFormat format) {
    final pending = _pendingLoads[format];
    if (pending != null) return pending;
    _discardedDuringLoad.remove(format);
    final completer = Completer<void>();
    _loadCompleters[format] = completer;
    final operation = _requestLoad(format, completer)
        .timeout(_configuration.loadTimeout)
        .whenComplete(() {
      _pendingLoads.remove(format);
      if (identical(_loadCompleters[format], completer)) {
        _loadCompleters.remove(format);
      }
    });
    _pendingLoads[format] = operation;
    return operation;
  }

  Future<void> _requestLoad(AdFormat format, Completer<void> completer) async {
    // Inventory the SDK already holds — from a load whose result was discarded,
    // for instance — is usable without another request.
    if (await _client.isLoaded(format)) {
      _ready[format] = true;
      if (!completer.isCompleted) completer.complete();
    } else {
      await _client.cache(format);
    }
    return completer.future;
  }

  @override
  bool isReady(AdPlacement placement) {
    return _fullScreen.contains(placement.format) &&
        _configuration.placementFor(placement) != null &&
        servesInventory &&
        _ready[placement.format] == true;
  }

  @override
  Future<KitResult<AdShowResult>> show(AdPlacement placement) async {
    final configured = _configuration.placementFor(placement);
    if (configured == null) return _unknownPlacement<AdShowResult>(placement);
    if (!_fullScreen.contains(placement.format)) {
      return _inlineOnly<AdShowResult>(placement);
    }
    if (!isReady(placement)) {
      return const KitSuccess<AdShowResult>(
        AdShowResult(status: AdShowStatus.notReady),
      );
    }
    return _guard(() => _show(placement, configured.name));
  }

  Future<AdShowResult> _show(AdPlacement placement, String name) async {
    final format = placement.format;
    // Dashboard rules for the placement, such as a frequency cap, can refuse
    // an ad that is loaded.
    if (!await _client.canShow(format, name)) {
      return const AdShowResult(status: AdShowStatus.notReady);
    }
    final completer = Completer<AdShowResult>();
    _showCompleters[format] = completer;
    _showing[format] = placement;
    _rewards.remove(format);
    _ready[format] = false;
    try {
      if (!await _client.show(format, name)) {
        return const AdShowResult(status: AdShowStatus.notReady);
      }
      return await completer.future
          .timeout(_configuration.fullScreenShowTimeout);
    } finally {
      if (identical(_showCompleters[format], completer)) {
        _showCompleters.remove(format);
      }
      _showing.remove(format);
    }
  }

  /// Forgets loaded inventory for [placement].
  ///
  /// Appodeal offers no way to drop a loaded full-screen ad, so the SDK keeps
  /// it; this provider stops reporting it ready and will not show it. The
  /// coordinator's premium policy is what keeps a premium user from seeing it.
  @override
  Future<KitResult<void>> discard(AdPlacement placement) async {
    if (_configuration.placementFor(placement) == null) {
      return _unknownPlacement<void>(placement);
    }
    final format = placement.format;
    if (_fullScreen.contains(format)) {
      _ready[format] = false;
      if (_pendingLoads.containsKey(format)) _discardedDuringLoad.add(format);
    }
    return const KitSuccess<void>(null);
  }

  /// Requests live or test inventory.
  ///
  /// Before initialization this selects the mode the SDK starts in. After it,
  /// inventory is withheld until the requested mode matches the one the SDK
  /// started in again — in practice, until the next launch.
  @override
  Future<KitResult<void>> setTestMode(bool enabled) async {
    if (enabled == _testMode) return const KitSuccess<void>(null);
    _testMode = enabled;
    final mode = enabled ? 'test' : 'live';
    if (!_initialized || _disposed) {
      _logger.log(
        KitLogLevel.info,
        'Appodeal will start with $mode inventory.',
        moduleId: moduleId,
      );
      return const KitSuccess<void>(null);
    }
    if (servesInventory) {
      _logger.log(
        KitLogLevel.info,
        'Appodeal is back in the mode it started in; inventory resumes.',
        moduleId: moduleId,
      );
    } else {
      _logger.log(
        KitLogLevel.warning,
        'Appodeal chooses test mode at initialization. No ads until the app '
        'relaunches with $mode inventory.',
        moduleId: moduleId,
      );
      for (final format in _fullScreen) {
        _ready[format] = false;
        if (_pendingLoads.containsKey(format)) _discardedDuringLoad.add(format);
      }
    }
    _setHealth(_health.state);
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _disposed = true;
    _initialized = false;
    await _callbackSubscription?.cancel();
    await _revenueSubscription?.cancel();
    for (final completer in _loadCompleters.values) {
      if (!completer.isCompleted) completer.complete();
    }
    for (final completer in _showCompleters.values) {
      if (!completer.isCompleted) {
        completer.complete(const AdShowResult(status: AdShowStatus.notReady));
      }
    }
    _loadCompleters.clear();
    _showCompleters.clear();
    KitResult<void> result = const KitSuccess<void>(null);
    try {
      await _client.dispose();
    } on Object catch (error, stackTrace) {
      result = KitFailure<void>(_mapError(error, stackTrace));
    }
    _setHealth(ModuleState.disposed);
    await _events.close();
    await _healthChanges.close();
    return result;
  }

  void _onCallback(AppodealCallback callback) {
    if (_disposed) return;
    final format = callback.format;
    switch (callback.type) {
      case AppodealCallbackType.loaded:
        if (!_fullScreen.contains(format)) {
          _emit(AdEventType.loaded, format);
          return;
        }
        final completer = _loadCompleters.remove(format);
        final discarded = _discardedDuringLoad.remove(format);
        if (!discarded && servesInventory) {
          _ready[format] = true;
          _emit(AdEventType.loaded, format);
        }
        if (completer != null && !completer.isCompleted) completer.complete();
      case AppodealCallbackType.failedToLoad:
        _discardedDuringLoad.remove(format);
        final completer = _loadCompleters.remove(format);
        if (completer != null && !completer.isCompleted) {
          completer.completeError(
            StateError('Appodeal had no ${format.name} ad to serve.'),
          );
        }
      case AppodealCallbackType.shown:
        _emit(AdEventType.impression, format);
      case AppodealCallbackType.clicked:
        _emit(AdEventType.clicked, format);
      case AppodealCallbackType.closed:
        _emit(AdEventType.dismissed, format);
        final completer = _showCompleters.remove(format);
        final reward = _rewards.remove(format);
        if (completer != null && !completer.isCompleted) {
          completer.complete(
            AdShowResult(status: AdShowStatus.shown, reward: reward),
          );
        }
      case AppodealCallbackType.showFailed:
        _rewards.remove(format);
        final completer = _showCompleters.remove(format);
        if (completer != null && !completer.isCompleted) {
          completer.completeError(
            StateError('Appodeal could not show the ${format.name} ad.'),
          );
        }
      case AppodealCallbackType.expired:
        _ready[format] = false;
      case AppodealCallbackType.rewarded:
        _rewards[format] = callback.reward;
    }
  }

  void _onRevenue(AppodealRevenueReport report) {
    if (_disposed) return;
    final format = report.format;
    final placement = format == null
        ? null
        : _showing[format] ??
            _configuration
                .placementReportedAs(format, report.placementName)
                ?.placement;
    // Logged either way. Only the winning network's adapter reports revenue,
    // and test ads never do, so these lines are how a release build confirms
    // revenue is arriving at all.
    final network =
        report.networkName.isEmpty ? 'an unnamed network' : report.networkName;
    final described = '${report.revenue} ${report.currency} from $network '
        '(${format?.name ?? 'an ad type this adapter does not serve'}, '
        'placement "${report.placementName}", '
        'precision ${report.precision.isEmpty ? 'unknown' : report.precision})';
    if (format == null || placement == null) {
      _logger.log(
        KitLogLevel.warning,
        'Appodeal revenue report not tracked, no configured placement '
        'matches it: $described.',
        moduleId: moduleId,
      );
      return;
    }
    _logger.log(
      KitLogLevel.info,
      'Appodeal revenue report received: $described.',
      moduleId: moduleId,
    );
    _add(
      AdEvent(
        type: AdEventType.paid,
        placement: placement,
        provider: providerId,
        occurredAt: _clock.now(),
        revenue: AdRevenue(
          valueMicros: (report.revenue * 1000000).round(),
          currencyCode: report.currency,
          provider: providerId,
          mediationNetwork:
              report.networkName.isEmpty ? null : report.networkName,
          adUnitName: report.adUnitName.isEmpty ? null : report.adUnitName,
          precision: report.precision.isEmpty ? null : report.precision,
        ),
      ),
    );
  }

  void _emit(AdEventType type, AdFormat format) {
    final placement = _showing[format] ??
        _configuration.placementReportedAs(format)?.placement;
    if (placement == null) return;
    _add(
      AdEvent(
        type: type,
        placement: placement,
        provider: providerId,
        occurredAt: _clock.now(),
      ),
    );
  }

  void _add(AdEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  // Android reports "Critical: …", "NonCritical: …" and "InternalError: …".
  // Only a critical error means the SDK refused to start. An internal error is
  // one of its components failing while ad types still initialize, so it, and
  // any message in an unrecognised format, is judged by the ad types instead.
  static bool _isCritical(String error) => error.startsWith('Critical');

  Future<bool> _anyFormatInitialized() async {
    for (final format in _configuration.formats) {
      if (await _client.isInitialized(format)) return true;
    }
    return false;
  }

  KitError? _validateConfiguration() {
    if (_configuration.appKey.trim().isEmpty) {
      return const KitError(
        code: KitErrorCode.invalidConfiguration,
        message: 'An Appodeal app key is required.',
      );
    }
    if (_configuration.placements.isEmpty) {
      return const KitError(
        code: KitErrorCode.invalidConfiguration,
        message: 'At least one Appodeal placement is required.',
      );
    }
    if (_configuration.initializationTimeout <= Duration.zero ||
        _configuration.loadTimeout <= Duration.zero ||
        _configuration.fullScreenShowTimeout <= Duration.zero) {
      return const KitError(
        code: KitErrorCode.invalidConfiguration,
        message: 'Appodeal timeouts must be positive.',
      );
    }
    for (final configured in _configuration.placements.values) {
      if (configured.placement.id.trim().isEmpty ||
          configured.name.trim().isEmpty) {
        return const KitError(
          code: KitErrorCode.invalidConfiguration,
          message: 'Appodeal placement IDs and names must not be empty.',
        );
      }
      if (!_formats.contains(configured.placement.format)) {
        return KitError(
          code: KitErrorCode.unsupported,
          message: 'Appodeal adapter does not support '
              '${configured.placement.format.name}.',
        );
      }
    }
    return null;
  }

  Future<KitResult<T>> _guard<T>(Future<T> Function() operation) async {
    if (!_initialized || _disposed) return _notReady<T>();
    try {
      return KitSuccess<T>(await operation());
    } on Object catch (error, stackTrace) {
      return KitFailure<T>(_mapError(error, stackTrace));
    }
  }

  KitError _mapError(Object error, StackTrace stackTrace) {
    final timedOut = error is TimeoutException;
    _logger.log(
      KitLogLevel.warning,
      timedOut ? 'Appodeal did not respond in time.' : 'Appodeal operation failed.',
      moduleId: moduleId,
      error: error,
      stackTrace: stackTrace,
    );
    return KitError(
      code: timedOut ? KitErrorCode.timeout : KitErrorCode.provider,
      message: timedOut
          ? 'Appodeal did not respond in time.'
          : 'Appodeal operation failed: $error',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  Future<KitResult<T>> _unknownPlacement<T>(AdPlacement placement) {
    return Future<KitResult<T>>.value(
      KitFailure<T>(
        KitError(
          code: KitErrorCode.invalidConfiguration,
          message: 'No Appodeal placement configured for ${placement.id}.',
        ),
      ),
    );
  }

  Future<KitResult<T>> _inlineOnly<T>(AdPlacement placement) {
    return Future<KitResult<T>>.value(
      KitFailure<T>(
        KitError(
          code: KitErrorCode.unsupported,
          message: '${placement.id} is a ${placement.format.name} placement; '
              'render it with AppodealBannerView.',
        ),
      ),
    );
  }

  KitFailure<T> _notReady<T>() {
    return KitFailure<T>(
      const KitError(
        code: KitErrorCode.notInitialized,
        message: 'Appodeal has not been initialized.',
      ),
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: providerId,
      state: state,
      observedAt: _clock.now(),
      error: error ?? _health.error,
      details: <String, Object?>{
        'testMode': _testMode,
        'sdkTestMode': _sdkTestMode,
        'servesInventory': servesInventory,
        'initializationWarnings': _initializationWarnings.length,
      },
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
