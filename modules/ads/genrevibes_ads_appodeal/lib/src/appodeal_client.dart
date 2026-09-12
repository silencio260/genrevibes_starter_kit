import 'dart:async';

import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';

/// Callback kinds Appodeal reports for an ad format.
enum AppodealCallbackType {
  /// Inventory finished loading.
  loaded,

  /// Loading failed. With auto-cache off, nothing retries.
  failedToLoad,

  /// The creative was displayed.
  shown,

  /// The creative could not be displayed.
  showFailed,

  /// The user clicked the creative.
  clicked,

  /// A full-screen creative was dismissed.
  closed,

  /// Loaded inventory expired before it was shown.
  expired,

  /// A rewarded video was watched far enough to earn its reward.
  rewarded,
}

/// One SDK callback, normalized.
final class AppodealCallback {
  /// Creates a callback.
  const AppodealCallback({
    required this.type,
    required this.format,
    this.reward,
  });

  /// What happened.
  final AppodealCallbackType type;

  /// Format it happened to.
  final AdFormat format;

  /// The reward, on [AppodealCallbackType.rewarded].
  final AdReward? reward;
}

/// Impression-level revenue as Appodeal reports it.
final class AppodealRevenueReport {
  /// Creates a revenue report.
  const AppodealRevenueReport({
    required this.format,
    required this.placementName,
    required this.revenue,
    required this.currency,
    required this.networkName,
    required this.adUnitName,
    required this.precision,
  });

  /// Format of the impression, or null for one this adapter does not serve.
  final AdFormat? format;

  /// Appodeal placement name the impression was shown under.
  final String placementName;

  /// Revenue in whole units of [currency].
  final double revenue;

  /// ISO 4217 currency code.
  final String currency;

  /// Mediated network that served the impression.
  final String networkName;

  /// Ad unit name within that network.
  final String adUnitName;

  /// How exact [revenue] is, as the SDK reports it.
  final String precision;
}

/// Injectable boundary around the Appodeal SDK.
abstract interface class AppodealClient {
  /// Callbacks for every format.
  Stream<AppodealCallback> get callbacks;

  /// Impression-level revenue for every format.
  Stream<AppodealRevenueReport> get revenue;

  /// Configures and initializes the SDK.
  ///
  /// Completes with the errors the SDK reported, empty when there were none.
  Future<List<String>> initialize({
    required String appKey,
    required Set<AdFormat> formats,
    required bool testMode,
    required bool verboseLogging,
    required bool childDirectedTreatment,
  });

  /// Whether the SDK finished initializing [format].
  Future<bool> isInitialized(AdFormat format);

  /// Requests inventory for [format].
  Future<void> cache(AdFormat format);

  /// Whether the SDK holds loaded inventory for [format].
  Future<bool> isLoaded(AdFormat format);

  /// Whether dashboard rules for [placementName] allow showing [format] now.
  Future<bool> canShow(AdFormat format, String placementName);

  /// Shows [format] under [placementName]. False when the SDK refuses.
  Future<bool> show(AdFormat format, String placementName);

  /// Stops reporting callbacks and releases resources.
  Future<void> dispose();
}

/// Production Appodeal client.
///
/// Appodeal's callbacks are process-wide, one handler per format, so a process
/// should have exactly one client.
abstract interface class AppodealBannerControl {
  Future<void> stopBanner();
}

final class DefaultAppodealClient
    implements AppodealClient, AppodealBannerControl {
  @override
  Future<void> stopBanner() async {
    Appodeal.hide(AppodealAdType.Banner);
    Appodeal.destroy(AppodealAdType.Banner);
  }

  /// Creates the production client.
  DefaultAppodealClient({this.manualBannerCaching = false});

  /// Host requests banner inventory explicitly after checking access.
  final bool manualBannerCaching;

  final StreamController<AppodealCallback> _callbacks =
      StreamController<AppodealCallback>.broadcast();
  final StreamController<AppodealRevenueReport> _revenue =
      StreamController<AppodealRevenueReport>.broadcast();
  bool _registered = false;

  @override
  Stream<AppodealCallback> get callbacks => _callbacks.stream;

  @override
  Stream<AppodealRevenueReport> get revenue => _revenue.stream;

  @override
  Future<List<String>> initialize({
    required String appKey,
    required Set<AdFormat> formats,
    required bool testMode,
    required bool verboseLogging,
    required bool childDirectedTreatment,
  }) {
    _registerCallbacks();
    // Appodeal documents test mode as set before initialization.
    Appodeal.setTesting(testMode);
    Appodeal.setLogLevel(
      verboseLogging ? Appodeal.LogLevelVerbose : Appodeal.LogLevelNone,
    );
    Appodeal.setChildDirectedTreatment(childDirectedTreatment);
    // Full-screen inventory is requested by the provider, never by the SDK on
    // its own: a premium user must not load an ad, and the application decides
    // how long to wait before the first one. Banners are explicitly cached
    // only after the application confirms ad eligibility.
    if (manualBannerCaching) {
      Appodeal.setAdViewAutoResume(false);
      Appodeal.setAutoCache(AppodealAdType.Banner, false);
    }
    Appodeal.setAutoCache(AppodealAdType.Interstitial, false);
    Appodeal.setAutoCache(AppodealAdType.RewardedVideo, false);
    // Native inventory is requested by the view that will show it, so a user
    // who never reaches a native placement never loads one.
    Appodeal.setAutoCache(AppodealAdType.NativeAd, false);

    final completer = Completer<List<String>>();
    Appodeal.initialize(
      appKey: appKey,
      adTypes: <AppodealAdType>[
        for (final format in formats)
          if (_adTypeFor(format) case final type?) type,
      ],
      onInitializationFinished: (errors) {
        if (completer.isCompleted) return;
        completer.complete(<String>[
          for (final error in errors ?? const <ApdInitializationError>[])
            error.description,
        ]);
      },
    );
    return completer.future;
  }

  @override
  Future<bool> isInitialized(AdFormat format) =>
      Appodeal.isInitialized(_requireAdType(format));

  @override
  Future<void> cache(AdFormat format) async {
    Appodeal.cache(_requireAdType(format));
  }

  @override
  Future<bool> isLoaded(AdFormat format) =>
      Appodeal.isLoaded(_requireAdType(format));

  @override
  Future<bool> canShow(AdFormat format, String placementName) =>
      Appodeal.canShow(_requireAdType(format), placementName);

  @override
  Future<bool> show(AdFormat format, String placementName) =>
      Appodeal.show(_requireAdType(format), placementName);

  @override
  Future<void> dispose() async {
    if (_registered) {
      Appodeal.setInterstitialCallbacks();
      Appodeal.setRewardedVideoCallbacks();
      Appodeal.setBannerCallbacks();
      Appodeal.setAdRevenueCallbacks();
      _registered = false;
    }
    await _callbacks.close();
    await _revenue.close();
  }

  // The plugin declares `bool`, `double` and `String` callback parameters but
  // passes platform-channel values through unchecked, so each is accepted as
  // `Object?` and read defensively.
  void _registerCallbacks() {
    if (_registered) return;
    _registered = true;
    const interstitial = AdFormat.interstitial;
    const rewarded = AdFormat.rewarded;
    const banner = AdFormat.banner;
    Appodeal.setInterstitialCallbacks(
      onInterstitialLoaded: (Object? _) =>
          _report(AppodealCallbackType.loaded, interstitial),
      onInterstitialFailedToLoad: () =>
          _report(AppodealCallbackType.failedToLoad, interstitial),
      onInterstitialShown: () =>
          _report(AppodealCallbackType.shown, interstitial),
      onInterstitialShowFailed: () =>
          _report(AppodealCallbackType.showFailed, interstitial),
      onInterstitialClicked: () =>
          _report(AppodealCallbackType.clicked, interstitial),
      onInterstitialClosed: () =>
          _report(AppodealCallbackType.closed, interstitial),
      onInterstitialExpired: () =>
          _report(AppodealCallbackType.expired, interstitial),
    );
    Appodeal.setRewardedVideoCallbacks(
      onRewardedVideoLoaded: (Object? _) =>
          _report(AppodealCallbackType.loaded, rewarded),
      onRewardedVideoFailedToLoad: () =>
          _report(AppodealCallbackType.failedToLoad, rewarded),
      onRewardedVideoShown: () => _report(AppodealCallbackType.shown, rewarded),
      onRewardedVideoShowFailed: () =>
          _report(AppodealCallbackType.showFailed, rewarded),
      onRewardedVideoClicked: () =>
          _report(AppodealCallbackType.clicked, rewarded),
      onRewardedVideoFinished: (Object? amount, Object? reward) => _add(
        AppodealCallback(
          type: AppodealCallbackType.rewarded,
          format: rewarded,
          reward: AdReward(
            type: reward?.toString() ?? '',
            amount: amount is num ? amount : 0,
          ),
        ),
      ),
      onRewardedVideoClosed: (Object? _) =>
          _report(AppodealCallbackType.closed, rewarded),
      onRewardedVideoExpired: () =>
          _report(AppodealCallbackType.expired, rewarded),
    );
    Appodeal.setBannerCallbacks(
      onBannerLoaded: (Object? _) =>
          _report(AppodealCallbackType.loaded, banner),
      onBannerFailedToLoad: () =>
          _report(AppodealCallbackType.failedToLoad, banner),
      onBannerShown: () => _report(AppodealCallbackType.shown, banner),
      onBannerShowFailed: () =>
          _report(AppodealCallbackType.showFailed, banner),
      onBannerClicked: () => _report(AppodealCallbackType.clicked, banner),
      onBannerExpired: () => _report(AppodealCallbackType.expired, banner),
    );
    Appodeal.setAdRevenueCallbacks(
      onAdRevenueReceive: (revenue) {
        if (_revenue.isClosed) return;
        _revenue.add(
          AppodealRevenueReport(
            format: _formatFor(revenue.adType),
            placementName: revenue.placement,
            revenue: revenue.revenue,
            currency: revenue.currency,
            networkName: revenue.networkName,
            adUnitName: revenue.adUnitName,
            precision: revenue.revenuePrecision,
          ),
        );
      },
    );
  }

  void _report(AppodealCallbackType type, AdFormat format) =>
      _add(AppodealCallback(type: type, format: format));

  void _add(AppodealCallback callback) {
    if (!_callbacks.isClosed) _callbacks.add(callback);
  }

  static AppodealAdType? _adTypeFor(AdFormat format) => switch (format) {
        AdFormat.banner => AppodealAdType.Banner,
        AdFormat.interstitial => AppodealAdType.Interstitial,
        AdFormat.rewarded => AppodealAdType.RewardedVideo,
        AdFormat.native => AppodealAdType.NativeAd,
        AdFormat.appOpen => null,
      };

  static AppodealAdType _requireAdType(AdFormat format) =>
      _adTypeFor(format) ??
      (throw UnsupportedError('Appodeal does not serve ${format.name} ads.'));

  static AdFormat? _formatFor(AppodealAdType type) => switch (type) {
        AppodealAdType.Banner ||
        AppodealAdType.BannerBottom ||
        AppodealAdType.BannerTop ||
        AppodealAdType.BannerLeft ||
        AppodealAdType.BannerRight =>
          AdFormat.banner,
        AppodealAdType.Interstitial => AdFormat.interstitial,
        AppodealAdType.RewardedVideo => AdFormat.rewarded,
        AppodealAdType.NativeAd => AdFormat.native,
        _ => null,
      };
}
