import 'dart:io';
import 'package:flutter/services.dart';
import 'package:yodo1_mas_flutter_plugin/constants.dart';
import 'package:yodo1_mas_flutter_plugin/yodo1_mas_flutter_plugin.dart';

import 'yodo1_configuration.dart';

/// One MAS ad event, as the SDK reports them: a numeric code and a message.
typedef Yodo1AdCallback = void Function(int code, String message);

/// Injectable boundary around the Yodo1 MAS plugin.
///
/// The plugin exposes eleven methods and no way to fake them, so the provider
/// talks to this interface and tests supply their own implementation.
abstract interface class Yodo1MasClient {
  /// Starts the SDK and reports whether it came up.
  Future<void> initialize(
    GenRevibesYodo1Configuration configuration,
    void Function(bool successful) onInitialized,
  );

  /// Requests inventory for [adType].
  Future<void> load(String adType);

  /// Whether inventory is ready for [adType].
  Future<bool> isLoaded(String adType);

  /// Displays inventory for [adType].
  Future<void> show(String adType, {String? placementId});

  /// Registers the per-format event callbacks.
  void listen({
    required Yodo1AdCallback onInterstitial,
    required Yodo1AdCallback onRewarded,
    required Yodo1AdCallback onAppOpen,
    required Yodo1AdCallback onBanner,
    required Yodo1AdCallback onNative,
  });

  /// Removes the callbacks registered by [listen].
  void stopListening();
}

/// MAS event codes, named.
abstract final class Yodo1AdEventCodes {
  /// Creative finished loading.
  static const loaded = Yodo1MasConstants.adEventLoaded;

  /// Creative could not be loaded.
  static const failedToLoad = Yodo1MasConstants.adEventFailedToLoad;

  /// Creative was displayed.
  static const opened = Yodo1MasConstants.adEventOpened;

  /// Creative could not be displayed.
  static const failedToOpen = Yodo1MasConstants.adEventFailedToOpen;

  /// Creative was dismissed.
  static const closed = Yodo1MasConstants.adEventClosed;

  /// Reward was earned on a rewarded creative.
  static const earned = Yodo1MasConstants.adEventEarned;
}

/// Production client backed by `yodo1_mas_flutter_plugin`.
final class DefaultYodo1MasClient implements Yodo1MasClient {
  /// Creates a production client.
  DefaultYodo1MasClient({Yodo1MasFlutterPlugin? plugin})
      : _plugin = plugin ?? Yodo1MasFlutterPlugin();

  final Yodo1MasFlutterPlugin _plugin;

  @override
  Future<void> initialize(
    GenRevibesYodo1Configuration configuration,
    void Function(bool successful) onInitialized,
  ) async {
    if (Platform.isAndroid) {
      final successful =
          await const MethodChannel('genrevibes.ads.yodo1/control')
              .invokeMethod<bool>('initialize', <String, Object>{
        'appKey': configuration.appKey.trim(),
        'privacy': configuration.useMasPrivacyDialog,
        'ccpa': configuration.ccpaOptOut,
        'coppa': configuration.coppaAgeRestricted,
        'gdpr': configuration.gdprConsentGranted,
      });
      onInitialized(successful == true);
      return;
    }
    _plugin.setInitListener(onInitialized);
    await _plugin.initSdk(
      configuration.appKey.trim(),
      configuration.useMasPrivacyDialog,
      configuration.ccpaOptOut,
      configuration.coppaAgeRestricted,
      configuration.gdprConsentGranted,
    );
  }

  @override
  Future<bool> isLoaded(String adType) => _plugin.isAdLoaded(adType);

  @override
  Future<void> load(String adType) => _plugin.loadAd(adType);

  @override
  Future<void> show(String adType, {String? placementId}) {
    return _plugin.showAd(adType, placementId: placementId);
  }

  @override
  void listen({
    required Yodo1AdCallback onInterstitial,
    required Yodo1AdCallback onRewarded,
    required Yodo1AdCallback onAppOpen,
    required Yodo1AdCallback onBanner,
    required Yodo1AdCallback onNative,
  }) {
    _plugin.setInterstitialListener(onInterstitial);
    _plugin.setRewardListener(onRewarded);
    _plugin.setAppOpenListener(onAppOpen);
    _plugin.setBannerListener(onBanner);
    _plugin.setNativeListener(onNative);
  }

  @override
  void stopListening() {
    _plugin.setInterstitialListener(null);
    _plugin.setRewardListener(null);
    _plugin.setAppOpenListener(null);
    _plugin.setBannerListener(null);
    _plugin.setNativeListener(null);
  }
}
