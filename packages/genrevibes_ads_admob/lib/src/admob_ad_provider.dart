import 'dart:async';

import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

import 'admob_client.dart';
import 'admob_configuration.dart';

/// Google Mobile Ads implementation of the GenreVibes ad-provider contract.
final class AdMobAdProvider implements AdProvider {
  /// Creates an AdMob provider.
  AdMobAdProvider({
    required GenreVibesAdMobConfiguration configuration,
    AdMobClient? client,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _configuration = configuration,
        _client = client ?? DefaultAdMobClient(clock: clock),
        _clock = clock,
        _logger = logger,
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

  final GenreVibesAdMobConfiguration _configuration;
  final AdMobClient _client;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  late ModuleHealth _health;
  bool _initialized = false;
  bool _disposed = false;

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
      () => _client.initialize(_configuration),
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
    final unit = _configuration.unitFor(placement);
    if (unit == null) return _unknownPlacement<void>(placement);
    return _guard(() => _client.load(unit));
  }

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
      if (unit.placement.id.trim().isEmpty || unit.adUnitId.trim().isEmpty) {
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
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
