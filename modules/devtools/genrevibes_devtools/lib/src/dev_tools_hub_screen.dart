import 'package:flutter/material.dart';

import 'dev_tools_host.dart';
import 'pages/analytics_page.dart';
import 'pages/capability_pages.dart';
import 'pages/developer_access_page.dart';
import 'pages/event_log_page.dart';
import 'pages/log_page.dart';
import 'pages/modules_page.dart';
import 'pages/remote_config_page.dart';
import 'pages/session_replay_page.dart';

/// The Starter Kit Lab.
///
/// One entry per capability. A capability the application has not wired shows
/// as unavailable rather than being hidden, so this doubles as a migration
/// checklist: what is greyed out is what is left to adopt.
class StarterKitLabScreen extends StatelessWidget {
  /// Creates the hub.
  const StarterKitLabScreen({required this.host, super.key});

  /// Everything the bench may touch.
  final DevToolsHost host;

  @override
  Widget build(BuildContext context) {
    final entries = <_Entry>[
      _Entry(
        title: 'Modules',
        subtitle: '${host.kit.modules.length} registered · health and timeline',
        icon: Icons.widgets,
        build: () => DevModulesPage(kit: host.kit),
      ),
      _Entry(
        title: 'Analytics',
        subtitle: '${host.catalogue.events.length} events, fired individually',
        icon: Icons.insights,
        build: host.analytics == null
            ? null
            : () => DevAnalyticsPage(
                  pipeline: host.analytics!,
                  catalogue: host.catalogue,
                ),
        missing: 'genrevibes_analytics',
      ),
      _Entry(
        title: 'Session replay',
        subtitle: host.sessionReplay == null
            ? 'not wired'
            : host.sessionReplay!.plan.recording
                ? 'recording · ${host.sessionReplay!.plan.percentOfUsers}% rollout'
                : 'not recording · '
                    '${host.sessionReplay!.plan.percentOfUsers}% rollout',
        icon: Icons.videocam,
        build: host.sessionReplay == null
            ? null
            : () => DevSessionReplayPage(controller: host.sessionReplay!),
        missing: 'a SessionReplayController passed from bootstrap',
      ),
      _Entry(
        title: 'Event log',
        subtitle: 'Every analytics event the app emits, live',
        icon: Icons.receipt_long,
        build: host.eventLog == null
            ? null
            : () => DevEventLogPage(observer: host.eventLog!),
        missing: 'a RecordingDeliveryObserver passed from bootstrap',
      ),
      _Entry(
        title: 'Kit log',
        subtitle: 'What every module reported',
        icon: Icons.article,
        build:
            host.logger == null ? null : () => DevLogPage(logger: host.logger!),
        missing: 'a RecordingKitLogger passed from bootstrap',
      ),
      _Entry(
        title: 'Remote config',
        subtitle: host.remoteConfigSchema == null
            ? 'not wired'
            : '${host.remoteConfigSchema!.keys.length} keys',
        icon: Icons.tune,
        build: host.remoteConfig == null || host.remoteConfigSchema == null
            ? null
            : () => DevRemoteConfigPage(
                  coordinator: host.remoteConfig!,
                  schema: host.remoteConfigSchema!,
                ),
        missing: 'genrevibes_remote_config',
      ),
      _Entry(
        title: 'Ads',
        subtitle: 'Load, show, and why one is blocked',
        icon: Icons.ads_click,
        build: host.ads == null
            ? null
            : () => DevAdsPage(
                  provider: host.ads!,
                  policy: host.adPolicy,
                  placements: host.adPlacements,
                ),
        missing: 'genrevibes_ads',
      ),
      _Entry(
        title: 'Consent',
        subtitle: 'UMP snapshot and forms',
        icon: Icons.privacy_tip,
        build:
            host.consent == null ? null : () => DevConsentPage(gate: host.consent!),
        missing: 'genrevibes_consent',
      ),
      _Entry(
        title: 'Purchases',
        subtitle: 'Entitlements, products, paywall',
        icon: Icons.shopping_cart,
        build: host.iap == null
            ? null
            : () => DevPurchasesPage(provider: host.iap!),
        missing: 'genrevibes_iap',
      ),
      _Entry(
        title: 'Push',
        subtitle: 'Subscription, permission, tags',
        icon: Icons.notifications_active,
        build:
            host.push == null ? null : () => DevPushPage(provider: host.push!),
        missing: 'genrevibes_notifications',
      ),
      _Entry(
        title: 'Local notifications',
        subtitle: 'Show, schedule, list pending',
        icon: Icons.schedule,
        build: host.localNotifications == null
            ? null
            : () => DevNotificationsPage(scheduler: host.localNotifications!),
        missing: 'genrevibes_notifications_local',
      ),
      _Entry(
        title: 'Permissions',
        subtitle: 'Check and request every kind',
        icon: Icons.lock_open,
        build: host.permissions == null
            ? null
            : () => DevPermissionsPage(provider: host.permissions!),
        missing: 'genrevibes_permissions',
      ),
      _Entry(
        title: 'Identity & engagement',
        subtitle: 'Install id, retention, targeting',
        icon: Icons.fingerprint,
        build: host.identity == null && host.retention == null
            ? null
            : () => DevIdentityPage(
                  identity: host.identity,
                  retention: host.retention,
                ),
        missing: 'genrevibes_device_identity / genrevibes_engagement',
      ),
      _Entry(
        title: 'Developer access',
        subtitle: host.developerAccess == null
            ? 'not wired'
            : describeDeveloperAccess(host.developerAccess!.current.reason),
        icon: Icons.admin_panel_settings,
        build: host.developerAccess == null
            ? null
            : () => DevDeveloperAccessPage(controller: host.developerAccess!),
        missing: 'genrevibes_developer_access',
      ),
      _Entry(
        title: 'Storage',
        subtitle: 'Namespaced keys beside their legacy keys',
        icon: Icons.storage,
        build: host.store == null
            ? null
            : () => DevStoragePage(
                  store: host.store!,
                  groups: host.storageKeys,
                ),
        missing: 'genrevibes_storage',
      ),
      _Entry(
        title: 'Crash',
        subtitle: 'Non-fatal, breadcrumb, uncaught',
        icon: Icons.bug_report,
        build: host.crash == null
            ? null
            : () => DevCrashPage(crash: host.crash!),
        missing: 'genrevibes_crash',
      ),
      _Entry(
        title: 'Feedback',
        subtitle: 'Submit feedback, contact, rating',
        icon: Icons.feedback,
        build: host.feedback == null
            ? null
            : () => DevFeedbackPage(provider: host.feedback!),
        missing: 'genrevibes_feedback',
      ),
    ];

    final adopted = entries.where((entry) => entry.build != null).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Starter Kit Lab')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              '$adopted of ${entries.length} capabilities wired',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (final entry in entries) _EntryTile(entry: entry),
        ],
      ),
    );
  }
}

class _Entry {
  const _Entry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.build,
    this.missing,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// Null when the application has not wired this capability.
  final Widget Function()? build;

  /// What to adopt to enable it.
  final String? missing;
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    final available = entry.build != null;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        enabled: available,
        leading: Icon(
          entry.icon,
          color: available ? scheme.primary : scheme.outline,
        ),
        title: Text(entry.title),
        subtitle: Text(
          available
              ? entry.subtitle
              : 'Not adopted — needs ${entry.missing}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: available
            ? const Icon(Icons.chevron_right)
            : Icon(Icons.block, size: 16, color: scheme.outline),
        onTap: available
            ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => entry.build!()),
                )
            : null,
      ),
    );
  }
}
