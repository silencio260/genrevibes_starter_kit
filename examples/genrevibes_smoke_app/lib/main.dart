import 'package:flutter/material.dart';
import 'package:genrevibes_ads_admob/genrevibes_ads_admob.dart';
import 'package:genrevibes_ads_admob_ui/genrevibes_ads_admob_ui.dart';
import 'package:genrevibes_analytics_firebase/genrevibes_analytics_firebase.dart';
import 'package:genrevibes_analytics_mixpanel/genrevibes_analytics_mixpanel.dart';
import 'package:genrevibes_analytics_mixpanel_replay/genrevibes_analytics_mixpanel_replay.dart';
import 'package:genrevibes_analytics_posthog/genrevibes_analytics_posthog.dart';
import 'package:genrevibes_iap_revenuecat/genrevibes_iap_revenuecat.dart';
import 'package:genrevibes_iap_revenuecat_ui/genrevibes_iap_revenuecat_ui.dart';
import 'package:genrevibes_notifications_local/genrevibes_notifications_local.dart';
import 'package:genrevibes_notifications_onesignal/genrevibes_notifications_onesignal.dart';
import 'package:genrevibes_remote_config_firebase/genrevibes_remote_config_firebase.dart';
import 'package:genrevibes_remote_config_shared_preferences/genrevibes_remote_config_shared_preferences.dart';
import 'package:genrevibes_starter_kit/genrevibes_starter_kit.dart';

void main() => runApp(const SmokeApp());

/// Provider types referenced by this example so every adapter is compiled.
const adapterTypes = <Type>[
  AdMobAdProvider,
  AdMobBannerView,
  FirebaseAnalyticsSink,
  MixpanelAnalyticsSink,
  MixpanelReplayController,
  PostHogAnalyticsSink,
  RevenueCatIapProvider,
  RevenueCatUiAdapter,
  PersistentLocalNotificationScheduler,
  OneSignalPushProvider,
  GenreVibesFirebaseRemoteConfigProvider,
  SharedPreferencesRemoteConfigCache,
  GenreVibesStarterKit,
];

class SmokeApp extends StatelessWidget {
  const SmokeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GenreVibes native smoke app',
      home: Scaffold(
        appBar: AppBar(title: const Text('GenreVibes native smoke app')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            const Text(
              'This app compiles and registers every current native adapter. '
              'It deliberately does not initialize providers because no SDK '
              'keys belong in the repository.',
            ),
            const SizedBox(height: 16),
            for (final type in adapterTypes)
              ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle_outline),
                title: Text(type.toString()),
              ),
          ],
        ),
      ),
    );
  }
}
