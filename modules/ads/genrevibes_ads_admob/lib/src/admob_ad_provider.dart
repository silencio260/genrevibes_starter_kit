import 'dart:async';

import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

import 'admob_client.dart';
import 'admob_configuration.dart';

/// Google Mobile Ads implementation of the GenRevibes ad-provider contract.
///
/// In test mode every request goes to Google's sample unit for its format
/// instead of the configured one. Sample units serve Google test ads only and
/// never mediate, so nothing a tester taps counts against any account.
final class AdMobAdProvider implements AdProvider, AdTestModeProvider {
  /// Creates an AdMob provider.
  ///
  /// [testMode] is the mode to start in. It can change later through
  /// [setTestMode], before or after initialization.
  AdMobAdProvider({
    required GenRevibesAdMobConfiguration configuration,
    AdMobClient? client,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
    bool testMode = false,
  })  : _configuration = configuration,
        _client = client ?? DefaultAdMobClient(clock: clock),
        _clock = clock,
        _logger = logger,
        _testMode = testMode,
        _health = ModuleHealth(
          moduleId: 'ads.admob',
          provider: 'admob',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  static const Set<AdFormat> _formats = <AdFormat>{
    AdFormat.interstitial,
    AdFormat.rewarded,
    AdFormat.appOpen,
  };

  final GenRevibesAdMobConfiguration _configuration;
  final AdMobClient _client;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  late ModuleHealth _health;
  late final GenRevibesAdMobConfiguration _testConfiguration =
      _configuration.withTestAdUnits();
  bool _testMode;
  bool _initialized = false;
  bool _disposed = false;

  /// The configuration requests are made against right now.
  GenRevibesAdMobConfiguration get _served =>
      _testMode ? _testConfiguration : _configuration;

  @override
  String get moduleId => 'ads.admob';

  @override
  String get providerId => 'admob';

  @override
  Set<AdFormat> get supportedFormats => _formats;

  @override
  Stream<AdEvent> get events => _client.events;

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  Future<KitResult<void>> initialize() async {
    if (_initialized) return const KitSuccess<void>(null);
    if (_disposed) return _notReady<void>();
    final error = _validateConfiguration();
    if (error != null) {
      _setHealth(ModuleState.failed, error: error);
      return KitFailure<void>(error);
    }
    _setHealth(ModuleState.initializing);
    final result = await _guard(
      () => _client.initialize(_served),
      requireInitialized: false,
    );
    if (result.isFailure) {
      final failure = result.fold(onSuccess: (_) => null, onFailure: (e) => e);
      _setHealth(ModuleState.failed, error: failure);
      return result;
    }
    _initialized = true;
    _setHealth(ModuleState.ready);
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> load(AdPlacement placement) {
    final unit = _served.unitFor(placement);
    if (unit == null) return _unknownPlacement<void>(placement);
    return _guard(() => _client.load(unit));
  }

  @override
  bool get isTestMode => _testMode;

  /// Switches between the configured units and Google's sample units.
  ///
  /// Discards every loaded ad, because inventory loaded in one mode must not be
  /// shown in the other: a live creative loaded moments before a developer
  /// device was recognised is exactly the ad that must not be tapped.
  @override
  Future<KitResult<void>> setTestMode(bool enabled) async {
    if (enabled == _testMode) return const KitSuccess<void>(null);
    _testMode = enabled;
    _logger.log(
      KitLogLevel.info,
      'AdMob switched to ${enabled ? 'test' : 'live'} inventory.',
      moduleId: moduleId,
    );
    if (!_initialized || _disposed) return const KitSuccess<void>(null);
    KitError? firstFailure;
    for (final unit in _configuration.adUnits.values) {
      final result = await _guard(() => _client.discard(unit.placement));
      result.fold(
        onSuccess: (_) {},
        onFailure: (error) => firstFailure ??= error,
      );
    }
    _setHealth(ModuleState.ready);
    return firstFailure == null
        ? const KitSuccess<void>(null)
        : KitFailure<void>(firstFailure!);
  }

  /// The unit a request for [placement] goes to right now, for reporting.
  AdMobAdUnit? servedUnitFor(AdPlacement placement) =>
      _served.unitFor(placement);

  @override
  bool isReady(AdPlacement placement) {
    return _initialized && !_disposed && _client.isReady(placement);
  }

  @override
  Future<KitResult<AdShowResult>> show(AdPlacement placement) {
    if (_configuration.unitFor(placement) == null) {
      return _unknownPlacement<AdShowResult>(placement);
    }
    return _guard(() => _client.show(placement));
  }

  @override
  Future<KitResult<void>> discard(AdPlacement placement) {
    if (_configuration.unitFor(placement) == null) {
      return _unknownPlacement<void>(placement);
    }
    return _guard(() => _client.discard(placement));
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    KitResult<void> result = const KitSuccess<void>(null);
    if (_initialized) result = await _guard(_client.dispose);
    _initialized = false;
    _disposed = true;
    _setHealth(ModuleState.disposed);
    await _healthChanges.close();
    return result;
  }

  KitError? _validateConfiguration() {
    if (_configuration.adUnits.isEmpty) {
      return const KitError(
        code: KitErrorCode.invalidConfiguration,
        message: 'At least one AdMob ad unit is required.',
      );
    }
    if (_configuration.fullScreenShowTimeout <= Duration.zero) {
      return const KitError(
        code: KitErrorCode.invalidConfiguration,
        message: 'AdMob full-screen show timeout must be positive.',
      );
    }
    for (final unit in _configuration.adUnits.values) {
      // A blank unit is acceptable in test mode, which never requests it.
      if (unit.placement.id.trim().isEmpty ||
          (!_testMode && unit.adUnitId.trim().isEmpty)) {
        return const KitError(
          code: KitErrorCode.invalidConfiguration,
          message: 'AdMob placement and ad-unit IDs must not be empty.',
        );
      }
      if (!_formats.contains(unit.placement.format)) {
        return KitError(
          code: KitErrorCode.unsupported,
          message:
              'AdMob full-screen adapter does not support ${unit.placement.format.name}.',
        );
      }
    }
    return null;
  }

  Future<KitResult<T>> _guard<T>(
    Future<T> Function() operation, {
    bool requireInitialized = true,
  }) async {
    if (requireInitialized && (!_initialized || _disposed)) {
      return _notReady<T>();
    }
    try {
      return KitSuccess<T>(await operation());
    } on Object catch (error, stackTrace) {
      _logger.log(
        KitLogLevel.warning,
        'AdMob operation failed.',
        moduleId: moduleId,
        error: error,
        stackTrace: stackTrace,
      );
      return KitFailure<T>(
        KitError(
          code: KitErrorCode.provider,
          message: 'AdMob operation failed: $error',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<KitResult<T>> _unknownPlacement<T>(AdPlacement placement) {
    return Future<KitResult<T>>.value(
      KitFailure<T>(
        KitError(
          code: KitErrorCode.invalidConfiguration,
          message: 'No AdMob unit configured for ${placement.id}.',
        ),
      ),
    );
  }

  KitFailure<T> _notReady<T>() {
    return KitFailure<T>(
      const KitError(
        code: KitErrorCode.notInitialized,
        message: 'AdMob has not been initialized.',
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
      details: <String, Object?>{'testMode': _testMode},
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
