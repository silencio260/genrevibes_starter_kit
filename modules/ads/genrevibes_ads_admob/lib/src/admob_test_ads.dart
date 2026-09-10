import 'package:flutter/foundation.dart';
import 'package:genrevibes_ads/genrevibes_ads.dart';

/// Google's public sample AdMob identifiers.
///
/// Every build that is not going to the store should request these instead of
/// the app's own units. Google's test-ads guide says of them: "These ad units
/// are not associated with your AdMob account, so there's no risk of your
/// account generating invalid traffic when using these ad units." For the same
/// reason they keep filling while an account is suspended or not yet approved,
/// when the app's own units serve nothing.
///
/// Values are copied from Google's test-ads and quick-start pages for Android
/// and iOS. The quick starts pair them with the sample app IDs below: "While
/// testing, use the sample app ID shown in the previous example."
abstract final class AdMobTestAds {
  /// The publisher every sample identifier belongs to.
  static const String publisherId = 'ca-app-pub-3940256099942544';

  /// Sample app ID for `com.google.android.gms.ads.APPLICATION_ID`.
  static const String androidAppId = 'ca-app-pub-3940256099942544~3347511713';

  /// Sample app ID for `GADApplicationIdentifier`.
  static const String iosAppId = 'ca-app-pub-3940256099942544~1458002511';

  /// Android sample units by format.
  ///
  /// Banners use the fixed-size unit, matching `AdSize.banner`, the default in
  /// `genrevibes_ads_admob_ui`.
  static const Map<AdFormat, String> androidUnitIds = <AdFormat, String>{
    AdFormat.banner: 'ca-app-pub-3940256099942544/6300978111',
    AdFormat.interstitial: 'ca-app-pub-3940256099942544/1033173712',
    AdFormat.rewarded: 'ca-app-pub-3940256099942544/5224354917',
    AdFormat.appOpen: 'ca-app-pub-3940256099942544/9257395921',
    AdFormat.native: 'ca-app-pub-3940256099942544/2247696110',
  };

  /// iOS sample units by format.
  static const Map<AdFormat, String> iosUnitIds = <AdFormat, String>{
    AdFormat.banner: 'ca-app-pub-3940256099942544/2934735716',
    AdFormat.interstitial: 'ca-app-pub-3940256099942544/4411468910',
    AdFormat.rewarded: 'ca-app-pub-3940256099942544/1712485313',
    AdFormat.appOpen: 'ca-app-pub-3940256099942544/5575463023',
    AdFormat.native: 'ca-app-pub-3940256099942544/3986624511',
  };

  /// The sample unit for [format] on [platform], or the running platform.
  static String unitIdFor(AdFormat format, {TargetPlatform? platform}) {
    final units = (platform ?? defaultTargetPlatform) == TargetPlatform.iOS
        ? iosUnitIds
        : androidUnitIds;
    return units[format]!;
  }

  /// Whether [adUnitId] is one of Google's sample units rather than a real one.
  static bool isTestUnitId(String adUnitId) =>
      adUnitId.startsWith('$publisherId/');
}
