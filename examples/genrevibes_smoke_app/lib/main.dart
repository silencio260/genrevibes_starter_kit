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

import 'smoke_env.dart';

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
  GenRevibesFirebaseRemoteConfigProvider,
  SharedPreferencesRemoteConfigCache,
  GenRevibesStarterKit,
];

class SmokeApp extends StatelessWidget {
  const SmokeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final status = SmokeEnv.status;
    return MaterialApp(
      title: 'GenRevibes native smoke app',
      home: Scaffold(
        appBar: AppBar(title: const Text('GenRevibes native smoke app')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            const Text(
              'This app compiles and registers every current native adapter. '
              'Reaching this screen proves the native provider graph starts '
              'without crashing.',
            ),
            const SizedBox(height: 24),
            Text(
              'Configuration',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Supplied by --dart-define-from-file. No credential is committed '
              'or displayed; only whether each key resolved.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            for (final entry in status.entries)
              ListTile(
                dense: true,
                leading: Icon(
                  entry.value
                      ? Icons.check_circle
                      : Icons.remove_circle_outline,
                  color: entry.value ? Colors.green : Colors.grey,
                ),
                title: Text(entry.key),
                subtitle: Text(entry.value ? 'configured' : 'not configured'),
              ),
            const Divider(height: 32),
            Text(
              'Compiled adapters',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
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
