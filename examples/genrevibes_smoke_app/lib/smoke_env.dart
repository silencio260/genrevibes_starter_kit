import 'dart:io' show Platform;

import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_ads_admob/genrevibes_ads_admob.dart';
import 'package:genrevibes_analytics_mixpanel/genrevibes_analytics_mixpanel.dart';
import 'package:genrevibes_analytics_posthog/genrevibes_analytics_posthog.dart';
import 'package:genrevibes_iap_revenuecat/genrevibes_iap_revenuecat.dart';
import 'package:genrevibes_notifications_onesignal/genrevibes_notifications_onesignal.dart';

/// Compile-time configuration supplied through `--dart-define-from-file`.
///
/// Key names deliberately match the Story Saver `env/*.json` schema so a single
/// environment file can drive both the production app and this example. No
/// value is ever committed: the JSON file lives outside version control and its
/// values are injected at build time.
///
/// Values arrive as `String.fromEnvironment` constants, so an absent key is an
/// empty string rather than a crash. Every provider below is therefore optional
/// and reports itself as unconfigured when its key is missing.
abstract final class SmokeEnv {
  // --- Identity and analytics -------------------------------------------

  /// RevenueCat Android public SDK key.
  static const revenueCatAndroidKey = String.fromEnvironment(
    'revenue_cat_api_key_android',
  );

  /// RevenueCat iOS public SDK key.
  static const revenueCatIosKey = String.fromEnvironment(
    'revenue_cat_api_key_ios',
  );

  /// OneSignal application ID.
  static const oneSignalAppId = String.fromEnvironment('one_signal_app_id');

  /// PostHog project API key.
  static const postHogApiKey = String.fromEnvironment('posthog_api_key');

  /// PostHog ingestion host.
  static const postHogHost = String.fromEnvironment(
    'posthog_host',
    defaultValue: 'https://us.i.posthog.com',
  );

  /// Mixpanel project token.
  static const mixpanelToken = String.fromEnvironment('mixpanel_token');

  /// Whether this build should behave as a development build.
  static const developmentMode = bool.fromEnvironment(
    'development_mode',
    defaultValue: true,
  );

  // --- Ads ---------------------------------------------------------------

  // Ad unit IDs are NOT read from the environment file.
  //
  // Serving a production ad unit from a non-store build is invalid traffic
  // under the AdMob program policies and can suspend the account that owns the
  // unit. This example therefore always uses Google's public test units, which
  // are safe to commit and safe to request fills against.

  /// Google's public sample ad units for the current platform.
  static Map<AdFormat, String> get testAdUnits =>
      Platform.isIOS ? AdMobTestAds.iosUnitIds : AdMobTestAds.androidUnitIds;

  // --- Configuration builders -------------------------------------------

  /// AdMob configuration built entirely from committed test units.
  static GenRevibesAdMobConfiguration adMobConfiguration() {
    return GenRevibesAdMobConfiguration(
      adUnits: <AdMobAdUnit>[
        for (final entry in testAdUnits.entries)
          AdMobAdUnit(
            placement: AdPlacement(id: entry.key.name, format: entry.key),
            adUnitId: entry.value,
          ),
      ],
    );
  }

  /// RevenueCat configuration, or `null` when no key was supplied.
  static RevenueCatConfiguration? revenueCatConfiguration() {
    if (revenueCatAndroidKey.isEmpty && revenueCatIosKey.isEmpty) return null;
    return RevenueCatConfiguration(
      androidApiKey: revenueCatAndroidKey.isEmpty ? null : revenueCatAndroidKey,
      iosApiKey: revenueCatIosKey.isEmpty ? null : revenueCatIosKey,
      logging:
          developmentMode ? RevenueCatLogging.debug : RevenueCatLogging.errors,
    );
  }

  /// OneSignal configuration, or `null` when no application ID was supplied.
  static GenRevibesOneSignalConfiguration? oneSignalConfiguration() {
    if (oneSignalAppId.isEmpty) return null;
    return GenRevibesOneSignalConfiguration(
      appId: oneSignalAppId,
      verboseLogging: developmentMode,
    );
  }

  /// PostHog configuration, or `null` when no API key was supplied.
  static GenRevibesPostHogConfiguration? postHogConfiguration() {
    if (postHogApiKey.isEmpty) return null;
    return GenRevibesPostHogConfiguration(
      apiKey: postHogApiKey,
      host: postHogHost,
      debug: developmentMode,
    );
  }

  /// Mixpanel configuration, or `null` when no token was supplied.
  static GenRevibesMixpanelConfiguration? mixpanelConfiguration() {
    if (mixpanelToken.isEmpty) return null;
    return GenRevibesMixpanelConfiguration(
      token: mixpanelToken,
      loggingEnabled: developmentMode,
    );
  }

  /// Human-readable configuration status for every env-driven provider.
  ///
  /// Values are never rendered, only whether each key resolved.
  static Map<String, bool> get status => <String, bool>{
    'AdMob (committed test units)': true,
    'RevenueCat': revenueCatConfiguration() != null,
    'OneSignal': oneSignalConfiguration() != null,
    'PostHog': postHogConfiguration() != null,
    'Mixpanel': mixpanelConfiguration() != null,
  };
}
