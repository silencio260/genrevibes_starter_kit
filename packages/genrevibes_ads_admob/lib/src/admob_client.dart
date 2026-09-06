import 'dart:async';

import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'admob_configuration.dart';

/// Injectable boundary around Google Mobile Ads full-screen inventory.
abstract interface class AdMobClient {
  /// Provider events including impressions, clicks, dismissals, and revenue.
  Stream<AdEvent> get events;

  /// Initializes Google Mobile Ads.
  Future<void> initialize(GenRevibesAdMobConfiguration configuration);

  /// Loads [unit], coalescing concurrent requests for the same placement.
  Future<void> load(AdMobAdUnit unit);

  /// Whether [placement] currently has loaded inventory.
  bool isReady(AdPlacement placement);

  /// Shows and consumes loaded inventory.
  Future<AdShowResult> show(AdPlacement placement);

  /// Disposes loaded inventory for [placement].
  Future<void> discard(AdPlacement placement);

  /// Releases all loaded ads and client resources.
  Future<void> dispose();
}

/// Production Google Mobile Ads client.
final class DefaultAdMobClient implements AdMobClient {
  /// Creates a Google Mobile Ads client.
  DefaultAdMobClient({KitClock clock = const SystemKitClock()})
      : _clock = clock;

  final KitClock _clock;
  final Map<String, AdWithoutView> _loaded = <String, AdWithoutView>{};
  final Map<String, Future<void>> _pendingLoads = <String, Future<void>>{};
  final Map<String, AdPlacement> _placements = <String, AdPlacement>{};
  final Set<String> _discardedDuringLoad = <String>{};
  final StreamController<AdEvent> _events =
      StreamController<AdEvent>.broadcast();
  bool _disposed = false;
  Duration _fullScreenShowTimeout = const Duration(minutes: 2);

  @override
  Stream<AdEvent> get events => _events.stream;

  @override
  Future<void> initialize(GenRevibesAdMobConfiguration configuration) async {
    _fullScreenShowTimeout = configuration.fullScreenShowTimeout;
    if (configuration.testDeviceIds.isNotEmpty) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: configuration.testDeviceIds),
      );
    }
    await MobileAds.instance.initialize();
  }

  @override
  Future<void> load(AdMobAdUnit unit) {
    if (_loaded.containsKey(unit.placement.id)) return Future<void>.value();
    final pending = _pendingLoads[unit.placement.id];
    if (pending != null) return pending;
    _discardedDuringLoad.remove(unit.placement.id);
    _placements[unit.placement.id] = unit.placement;
    final operation = _load(unit).whenComplete(() {
      _pendingLoads.remove(unit.placement.id);
    });
    _pendingLoads[unit.placement.id] = operation;
    return operation;
  }

  Future<void> _load(AdMobAdUnit unit) {
    return switch (unit.placement.format) {
      AdFormat.interstitial => _loadInterstitial(unit),
      AdFormat.rewarded => _loadRewarded(unit),
      AdFormat.appOpen => _loadAppOpen(unit),
      AdFormat.banner || AdFormat.native => throw UnsupportedError(
          'AdMob inline formats use the optional presentation API.',
        ),
    };
  }

  Future<void> _loadInterstitial(AdMobAdUnit unit) async {
    final completer = Completer<void>();
    try {
      await InterstitialAd.load(
        adUnitId: unit.adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) => _completeLoad(unit.placement, ad, completer),
          onAdFailedToLoad: (error) => _failLoad(error, completer),
        ),
      );
    } on Object catch (error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    }
    return completer.future;
  }

  Future<void> _loadRewarded(AdMobAdUnit unit) async {
    final completer = Completer<void>();
    try {
      await RewardedAd.load(
        adUnitId: unit.adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) => _completeLoad(unit.placement, ad, completer),
          onAdFailedToLoad: (error) => _failLoad(error, completer),
        ),
      );
    } on Object catch (error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    }
    return completer.future;
  }

  Future<void> _loadAppOpen(AdMobAdUnit unit) async {
    final completer = Completer<void>();
    try {
      await AppOpenAd.load(
        adUnitId: unit.adUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) => _completeLoad(unit.placement, ad, completer),
          onAdFailedToLoad: (error) => _failLoad(error, completer),
        ),
      );
    } on Object catch (error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    }
    return completer.future;
  }

  void _completeLoad(
    AdPlacement placement,
    AdWithoutView ad,
    Completer<void> completer,
  ) {
    if (_disposed || _discardedDuringLoad.remove(placement.id)) {
      unawaited(ad.dispose());
      if (!completer.isCompleted) completer.complete();
      return;
    }
    final previous = _loaded[placement.id];
    if (previous != null) unawaited(previous.dispose());
    _loaded[placement.id] = ad;
    ad.onPaidEvent = (paidAd, valueMicros, _, currencyCode) {
      _emit(
        AdEvent(
          type: AdEventType.paid,
          placement: placement,
          provider: 'admob',
          occurredAt: _clock.now(),
          revenue: AdRevenue(
            valueMicros: valueMicros,
            currencyCode: currencyCode,
            provider: 'admob',
            mediationNetwork: paidAd.responseInfo?.mediationAdapterClassName,
          ),
        ),
      );
    };
    _emitEvent(AdEventType.loaded, placement);
    if (!completer.isCompleted) completer.complete();
  }

  void _failLoad(LoadAdError error, Completer<void> completer) {
    if (!completer.isCompleted) {
      completer.completeError(StateError(error.message));
    }
  }

  @override
  bool isReady(AdPlacement placement) => _loaded.containsKey(placement.id);

  @override
  Future<AdShowResult> show(AdPlacement placement) async {
    final ad = _loaded.remove(placement.id);
    if (ad == null) {
      return const AdShowResult(status: AdShowStatus.notReady);
    }
    return switch (ad) {
      InterstitialAd value => _showInterstitial(placement, value),
      RewardedAd value => _showRewarded(placement, value),
      AppOpenAd value => _showAppOpen(placement, value),
      _ => throw UnsupportedError('Unsupported loaded AdMob ad type.'),
    };
  }

  Future<AdShowResult> _showInterstitial(
    AdPlacement placement,
    InterstitialAd ad,
  ) async {
    final completer = Completer<AdShowResult>();
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdImpression: (_) => _emitEvent(AdEventType.impression, placement),
      onAdClicked: (_) => _emitEvent(AdEventType.clicked, placement),
      onAdDismissedFullScreenContent: (shownAd) {
        _dismiss(placement, shownAd, completer);
      },
      onAdFailedToShowFullScreenContent: (shownAd, error) {
        _failShow(shownAd, error, completer);
      },
    );
    try {
      await ad.show();
      return completer.future.timeout(_fullScreenShowTimeout);
    } on Object {
      await ad.dispose();
      rethrow;
    }
  }

  Future<AdShowResult> _showRewarded(
    AdPlacement placement,
    RewardedAd ad,
  ) async {
    final completer = Completer<AdShowResult>();
    AdReward? reward;
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdImpression: (_) => _emitEvent(AdEventType.impression, placement),
      onAdClicked: (_) => _emitEvent(AdEventType.clicked, placement),
      onAdDismissedFullScreenContent: (shownAd) {
        unawaited(shownAd.dispose());
        _emitEvent(AdEventType.dismissed, placement);
        if (!completer.isCompleted) {
          completer.complete(
            AdShowResult(status: AdShowStatus.shown, reward: reward),
          );
        }
      },
      onAdFailedToShowFullScreenContent: (shownAd, error) {
        _failShow(shownAd, error, completer);
      },
    );
    try {
      await ad.show(
        onUserEarnedReward: (_, item) {
          reward = AdReward(type: item.type, amount: item.amount);
        },
      );
      return completer.future.timeout(_fullScreenShowTimeout);
    } on Object {
      await ad.dispose();
      rethrow;
    }
  }

  Future<AdShowResult> _showAppOpen(
    AdPlacement placement,
    AppOpenAd ad,
  ) async {
    final completer = Completer<AdShowResult>();
    ad.fullScreenContentCallback = FullScreenContentCallback<AppOpenAd>(
      onAdImpression: (_) => _emitEvent(AdEventType.impression, placement),
      onAdClicked: (_) => _emitEvent(AdEventType.clicked, placement),
      onAdDismissedFullScreenContent: (shownAd) {
        _dismiss(placement, shownAd, completer);
      },
      onAdFailedToShowFullScreenContent: (shownAd, error) {
        _failShow(shownAd, error, completer);
      },
    );
    try {
      await ad.show();
      return completer.future.timeout(_fullScreenShowTimeout);
    } on Object {
      await ad.dispose();
      rethrow;
    }
  }

  void _dismiss<T extends Ad>(
    AdPlacement placement,
    T ad,
    Completer<AdShowResult> completer,
  ) {
    unawaited(ad.dispose());
    _emitEvent(AdEventType.dismissed, placement);
    if (!completer.isCompleted) {
      completer.complete(const AdShowResult(status: AdShowStatus.shown));
    }
  }

  void _failShow<T extends Ad>(
    T ad,
    AdError error,
    Completer<AdShowResult> completer,
  ) {
    unawaited(ad.dispose());
    if (!completer.isCompleted) {
      completer.completeError(StateError(error.message));
    }
  }

  void _emitEvent(AdEventType type, AdPlacement placement) {
    _emit(
      AdEvent(
        type: type,
        placement: placement,
        provider: 'admob',
        occurredAt: _clock.now(),
      ),
    );
  }

  void _emit(AdEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  @override
  Future<void> discard(AdPlacement placement) async {
    if (_pendingLoads.containsKey(placement.id)) {
      _discardedDuringLoad.add(placement.id);
    }
    await _loaded.remove(placement.id)?.dispose();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _discardedDuringLoad.addAll(_pendingLoads.keys);
    for (final ad in _loaded.values) {
      await ad.dispose();
    }
    _loaded.clear();
    _placements.clear();
    await _events.close();
  }
}
