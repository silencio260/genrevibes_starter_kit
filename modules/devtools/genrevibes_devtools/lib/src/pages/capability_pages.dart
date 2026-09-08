import 'package:flutter/material.dart';
import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_consent/genrevibes_consent.dart';
import 'package:genrevibes_crash/genrevibes_crash.dart';
import 'package:genrevibes_device_identity/genrevibes_device_identity.dart';
import 'package:genrevibes_engagement/genrevibes_engagement.dart';
import 'package:genrevibes_feedback/genrevibes_feedback.dart';
import 'package:genrevibes_iap/genrevibes_iap.dart';
import 'package:genrevibes_notifications/genrevibes_notifications.dart';
import 'package:genrevibes_permissions/genrevibes_permissions.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';

import '../dev_tools_host.dart';
import '../widgets/action_row.dart';
import '../widgets/dev_scaffold.dart';

/// Ads: what the policy currently permits, and the provider's own operations.
class DevAdsPage extends StatelessWidget {
  /// Creates the page.
  const DevAdsPage({required this.provider, super.key, this.policy, this.placements = const <AdPlacement>[]});

  /// Full-screen ad provider.
  final AdProvider provider;

  /// Policy, when the application wired one.
  final AdPolicyController? policy;

  /// Placements to exercise.
  final List<AdPlacement> placements;

  @override
  Widget build(BuildContext context) {
    final policy = this.policy;
    return DevScaffold(
      title: 'Ads',
      subtitle: '${provider.providerId} · supports '
          '${provider.supportedFormats.map((f) => f.name).join(", ")}',
      builder: (refresh) => <Widget>[
        if (policy != null) ...<Widget>[
          const DevHeading('Policy'),
          DevFact('Premium', '${policy.isPremium}'),
          DevFact(
            'Suppression reasons',
            policy.suppressionReasons.isEmpty
                ? 'none'
                : policy.suppressionReasons.join(', '),
          ),
          DevFact('Currently showing',
              policy.showingPlacement?.id ?? 'nothing'),
          ActionRow(
            label: 'Toggle premium suppression',
            icon: Icons.workspace_premium,
            run: () async {
              policy.setPremium(!policy.isPremium);
              refresh();
              return 'premium = ${policy.isPremium}';
            },
          ),
        ],
        for (final placement in placements) ...<Widget>[
          DevHeading('${placement.id}  (${placement.format.name})'),
          if (policy != null)
            DevFact(
              'Policy verdict',
              _verdict(policy.evaluate(placement)),
            ),
          DevFact('Provider ready', '${provider.isReady(placement)}'),
          ActionRow(
            label: 'Load',
            icon: Icons.download,
            timeout: const Duration(seconds: 30),
            run: () async {
              final result = await provider.load(placement);
              refresh();
              return result;
            },
          ),
          ActionRow(
            label: 'Show',
            icon: Icons.play_circle,
            timeout: const Duration(seconds: 60),
            run: () async {
              final result = await provider.show(placement);
              refresh();
              return result.map(
                (value) => 'status ${value.status.name}'
                    '${value.blockReason == null ? '' : ' · blocked by '
                        '${value.blockReason!.name}'}',
              );
            },
          ),
          ActionRow(
            label: 'Discard',
            icon: Icons.delete_outline,
            run: () async {
              final result = await provider.discard(placement);
              refresh();
              return result;
            },
          ),
        ],
      ],
    );
  }

  /// The block reason is the useful half — an ad that will not show says why.
  String _verdict(AdPolicyDecision decision) => decision.isAllowed
      ? 'allowed'
      : 'blocked · ${decision.blockReason?.name ?? "unknown"}';
}

/// Consent: the snapshot, the forms, and what it implies downstream.
class DevConsentPage extends StatelessWidget {
  /// Creates the page.
  const DevConsentPage({required this.gate, super.key});

  /// The gate under test.
  final ConsentGate gate;

  @override
  Widget build(BuildContext context) {
    return DevScaffold(
      title: 'Consent',
      subtitle: gate.snapshot.state.name,
      builder: (refresh) {
        final snapshot = gate.snapshot;
        return <Widget>[
          DevFact('State', snapshot.state.name),
          DevFact('Allows personalized work',
              '${snapshot.allowsPersonalizedWork}'),
          DevFact('Form available', '${snapshot.formAvailable}'),
          DevFact('Privacy options required',
              '${snapshot.privacyOptionsRequired}'),
          DevFact('Observed at', snapshot.observedAt.toIso8601String()),
          const DevHeading('Actions'),
          ActionRow(
            label: 'Show privacy options form',
            icon: Icons.privacy_tip,
            timeout: const Duration(seconds: 60),
            run: () async {
              final result = await gate.showPrivacyOptions();
              refresh();
              return result;
            },
          ),
          ActionRow(
            label: 'Reset consent',
            subtitle: 'Clears the stored decision. QA only.',
            icon: Icons.restart_alt,
            isDestructive: true,
            run: () async {
              final result = await gate.reset();
              refresh();
              return result;
            },
          ),
        ];
      },
    );
  }
}

/// Purchases: entitlements, products, and the hosted screens.
class DevPurchasesPage extends StatelessWidget {
  /// Creates the page.
  const DevPurchasesPage({required this.provider, super.key});

  /// Purchases provider.
  final IapProvider provider;

  @override
  Widget build(BuildContext context) {
    final capabilities = provider.capabilities;
    return DevScaffold(
      title: 'Purchases',
      subtitle: provider.providerId,
      builder: (refresh) => <Widget>[
        DevFact('Hosted paywall', '${capabilities.hostedPaywall}'),
        DevFact('Customer centre', '${capabilities.customerCenter}'),
        DevFact('Account identification',
            '${capabilities.accountIdentification}'),
        const DevHeading('Actions'),
        ActionRow(
          label: 'Read entitlements',
          icon: Icons.verified,
          run: () async {
            final result = await provider.getEntitlements();
            return result.map(
              (snapshot) => snapshot.activeEntitlementIds.isEmpty
                  ? 'no active entitlements (${snapshot.entitlements.length} known)'
                  : 'active: ${snapshot.activeEntitlementIds.join(", ")}',
            );
          },
        ),
        ActionRow(
          label: 'Force refresh entitlements',
          icon: Icons.sync,
          run: () async {
            final result = await provider.getEntitlements(forceRefresh: true);
            return result.map(
              (snapshot) => 'refreshed at ${snapshot.observedAt}',
            );
          },
        ),
        ActionRow(
          label: 'Fetch products',
          icon: Icons.shopping_bag,
          run: () async {
            final result = await provider.getProducts();
            return result.map(
              (products) => products.isEmpty
                  ? 'no products returned'
                  : products
                      .map((p) => '${p.id} ${p.priceString}')
                      .join('\n'),
            );
          },
        ),
        ActionRow(
          label: 'Present paywall',
          icon: Icons.payment,
          timeout: const Duration(minutes: 3),
          run: () async {
            final result = await provider.presentPaywall();
            return result.map((purchase) => purchase.status.name);
          },
        ),
        ActionRow(
          label: 'Present customer centre',
          icon: Icons.support_agent,
          timeout: const Duration(minutes: 3),
          run: provider.presentCustomerCenter,
        ),
        ActionRow(
          label: 'Restore purchases',
          icon: Icons.restore,
          timeout: const Duration(seconds: 60),
          run: () async {
            final result = await provider.restorePurchases();
            return result.map(
              (snapshot) => 'active: '
                  '${snapshot.activeEntitlementIds.join(", ").ifEmpty("none")}',
            );
          },
        ),
      ],
    );
  }
}

/// Push: the delivery diagnostics the provider already computes.
class DevPushPage extends StatelessWidget {
  /// Creates the page.
  const DevPushPage({required this.provider, super.key});

  /// Push provider.
  final PushNotificationProvider provider;

  @override
  Widget build(BuildContext context) {
    return DevScaffold(
      title: 'Push',
      subtitle: provider.providerId,
      builder: (refresh) => <Widget>[
        ActionRow(
          label: 'Read subscription state',
          subtitle: 'Renders toSafeDiagnostics(), which is PII-free.',
          icon: Icons.fact_check,
          run: () async {
            final result = await provider.getSubscriptionState();
            return result.map(
              (state) => state
                  .toSafeDiagnostics()
                  .entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join('\n'),
            );
          },
        ),
        ActionRow(
          label: 'Request permission',
          icon: Icons.notifications_active,
          timeout: const Duration(seconds: 60),
          run: () async {
            final result = await provider.requestPermission();
            return result.map((state) => state.permission.name);
          },
        ),
        ActionRow(
          label: 'Opt in',
          icon: Icons.login,
          run: () async {
            final result = await provider.optIn();
            return result.map((state) => 'optedIn ${state.optedIn}');
          },
        ),
        ActionRow(
          label: 'Opt out',
          icon: Icons.logout,
          run: () async {
            final result = await provider.optOut();
            return result.map((state) => 'optedIn ${state.optedIn}');
          },
        ),
        ActionRow(
          label: 'Set tag kit_lab=true',
          icon: Icons.sell,
          run: () => provider.setTags(const <String, String>{'kit_lab': 'true'}),
        ),
        ActionRow(
          label: 'Remove tag kit_lab',
          icon: Icons.sell_outlined,
          run: () => provider.removeTags(const <String>['kit_lab']),
        ),
      ],
    );
  }
}

/// Permissions: every kind, checked and requested one at a time.
class DevPermissionsPage extends StatelessWidget {
  /// Creates the page.
  const DevPermissionsPage({required this.provider, super.key});

  /// Permission provider.
  final PermissionProvider provider;

  static const _kinds = <PermissionKind>[
    PermissionKind.photos,
    PermissionKind.videos,
    PermissionKind.audio,
    PermissionKind.storage,
    PermissionKind.manageExternalStorage,
    PermissionKind.notifications,
    PermissionKind.camera,
    PermissionKind.microphone,
    PermissionKind.location,
  ];

  @override
  Widget build(BuildContext context) {
    final facts = provider.platform;
    return DevScaffold(
      title: 'Permissions',
      subtitle: provider.providerId,
      builder: (refresh) => <Widget>[
        DevFact('Android', '${facts.isAndroid} (sdk ${facts.androidSdkInt})'),
        DevFact('Split media permissions', '${facts.hasSplitMediaPermissions}'),
        const DevHeading('Check — no prompt'),
        ActionRow(
          label: 'Check every kind',
          icon: Icons.checklist,
          run: () async {
            final lines = <String>[];
            for (final kind in _kinds) {
              final result = await provider.check(kind);
              lines.add(
                '${kind.name}: ${result.fold(
                  onSuccess: (state) => state.name,
                  onFailure: (error) => 'error ${error.code.name}',
                )}',
              );
            }
            return lines.join('\n');
          },
        ),
        const DevHeading('Request — prompts'),
        for (final kind in _kinds)
          ActionRow(
            label: 'Request ${kind.name}',
            icon: Icons.lock_open,
            timeout: const Duration(seconds: 60),
            run: () async {
              final result = await provider.request(kind);
              return result.map((state) => state.name);
            },
          ),
        const DevHeading('Settings'),
        ActionRow(
          label: 'Open app settings',
          icon: Icons.settings,
          run: provider.openSettings,
        ),
      ],
    );
  }
}

/// Identity and engagement.
class DevIdentityPage extends StatelessWidget {
  /// Creates the page.
  const DevIdentityPage({super.key, this.identity, this.retention});

  /// Device identity resolver.
  final DeviceIdentityResolver? identity;

  /// Retention tracker.
  final RetentionTracker? retention;

  @override
  Widget build(BuildContext context) {
    final identity = this.identity;
    final retention = this.retention;
    return DevScaffold(
      title: 'Identity & engagement',
      builder: (refresh) => <Widget>[
        if (identity != null) ...<Widget>[
          const DevHeading('Device identity'),
          DevFact('Install id', identity.current?.installId ?? 'unresolved'),
          DevFact('Vendor id', identity.current?.vendorId ?? 'none'),
          DevFact('Advertising id', identity.current?.advertisingId ?? 'none'),
          DevFact('Tracking', identity.current?.tracking.name ?? '—'),
          ActionRow(
            label: 'Resolve',
            subtitle: 'No tracking prompt.',
            icon: Icons.fingerprint,
            run: () async {
              final result = await identity.resolve();
              refresh();
              return result.map((value) => value.installId);
            },
          ),
          ActionRow(
            label: 'Resolve and prompt for tracking',
            subtitle: 'Shows the ATT dialog on iOS.',
            icon: Icons.track_changes,
            timeout: const Duration(seconds: 60),
            run: () async {
              final result = await identity.resolve(promptTracking: true);
              refresh();
              return result.map((value) => value.tracking.name);
            },
          ),
        ],
        if (retention != null) ...<Widget>[
          const DevHeading('Engagement'),
          DevFact('Days since install',
              '${retention.snapshot.daysSinceInstall}'),
          DevFact('Total opens', '${retention.snapshot.totalOpens}'),
          DevFact('Active days', '${retention.snapshot.activeDays}'),
          DevFact('Sessions today', '${retention.snapshot.sessionsToday}'),
          DevFact('Segment', retention.profile.segment.name),
          DevFact('Level', retention.profile.level.name),
          DevFact('Score', '${retention.profile.score}'),
          const DevHeading('Targeting decisions'),
          for (final entry in retention.profile.decisions.toProperties().entries)
            DevFact(entry.key, '${entry.value}'),
          const DevHeading('Actions'),
          ActionRow(
            label: 'Record app open',
            icon: Icons.login,
            run: () async {
              final result = await retention.recordAppOpen();
              refresh();
              return result.map((s) => 'opens now ${s.totalOpens}');
            },
          ),
          ActionRow(
            label: 'Record session',
            icon: Icons.timer,
            run: () async {
              final result = await retention.recordSession();
              refresh();
              return result.map((s) => 'sessions today ${s.sessionsToday}');
            },
          ),
        ],
      ],
    );
  }
}

/// Crash reporting.
class DevCrashPage extends StatelessWidget {
  /// Creates the page.
  const DevCrashPage({required this.crash, super.key});

  /// Crash coordinator.
  final CrashCoordinator crash;

  @override
  Widget build(BuildContext context) {
    return DevScaffold(
      title: 'Crash',
      builder: (refresh) => <Widget>[
        DevFact('Collection enabled', '${crash.collectionEnabled}'),
        if (!crash.collectionEnabled)
          const DevNote(
            'Collection is off, which is normal in a debug build. Nothing '
            'recorded here will reach the dashboard.',
          ),
        const DevHeading('Actions'),
        ActionRow(
          label: 'Record a non-fatal',
          icon: Icons.bug_report,
          run: () => crash.report(
            CrashReport(
              error: StateError('Kit Lab non-fatal'),
              stackTrace: StackTrace.current,
              reason: 'Fired from the Starter Kit Lab',
            ),
          ),
        ),
        ActionRow(
          label: 'Log a breadcrumb',
          icon: Icons.timeline,
          run: () => crash.log('kit lab breadcrumb'),
        ),
        ActionRow(
          label: 'Set a custom key',
          icon: Icons.key,
          run: () => crash.setCustomKey('kit_lab', true),
        ),
        ActionRow(
          label: 'Throw an uncaught async error',
          subtitle: 'Goes to the guarded zone, not this row.',
          icon: Icons.error_outline,
          isDestructive: true,
          run: () async {
            Future<void>.error(StateError('Kit Lab uncaught async'));
            return 'thrown — check the zone handler and the log page';
          },
        ),
      ],
    );
  }
}

/// Feedback submission.
class DevFeedbackPage extends StatelessWidget {
  /// Creates the page.
  const DevFeedbackPage({required this.provider, super.key});

  /// Feedback provider.
  final FeedbackProvider provider;

  @override
  Widget build(BuildContext context) {
    return DevScaffold(
      title: 'Feedback',
      subtitle: provider.providerId,
      builder: (refresh) => <Widget>[
        ActionRow(
          label: 'Submit feedback',
          icon: Icons.feedback,
          timeout: const Duration(seconds: 30),
          run: () => provider.submit(
            FeedbackSubmission(
              message: 'Starter Kit Lab test submission',
            ),
          ),
        ),
        ActionRow(
          label: 'Submit contact message',
          icon: Icons.mail,
          timeout: const Duration(seconds: 30),
          run: () => provider.submit(
            FeedbackSubmission(
              message: 'Starter Kit Lab contact test',
              kind: FeedbackKind.contact,
              email: 'test@example.com',
            ),
          ),
        ),
        ActionRow(
          label: 'Submit a 5-star rating',
          icon: Icons.star,
          timeout: const Duration(seconds: 30),
          run: () =>
              provider.submitRatingAndReview(rating: 5, review: 'kit lab'),
        ),
      ],
    );
  }
}

/// Local notifications.
class DevNotificationsPage extends StatelessWidget {
  /// Creates the page.
  const DevNotificationsPage({required this.scheduler, super.key});

  /// Local scheduler.
  final LocalNotificationScheduler scheduler;

  @override
  Widget build(BuildContext context) {
    return DevScaffold(
      title: 'Local notifications',
      builder: (refresh) => <Widget>[
        ActionRow(
          label: 'Request permission',
          icon: Icons.notifications,
          timeout: const Duration(seconds: 60),
          run: scheduler.requestPermission,
        ),
        ActionRow(
          label: 'Show one now',
          icon: Icons.notification_add,
          run: () => scheduler.show(
            9001,
            const LocalNotificationContent(
              title: 'Starter Kit Lab',
              body: 'Fired from the bench.',
            ),
          ),
        ),
        ActionRow(
          label: 'Schedule one in 15 seconds',
          icon: Icons.schedule,
          run: () => scheduler.schedule(
            LocalNotificationRequest(
              id: 9002,
              content: const LocalNotificationContent(
                title: 'Starter Kit Lab',
                body: 'Scheduled fifteen seconds ago.',
              ),
              schedule: LocalNotificationOnce(
                DateTime.now().add(const Duration(seconds: 15)),
              ),
            ),
          ),
        ),
        ActionRow(
          label: 'List pending',
          icon: Icons.list,
          run: () async {
            final result = await scheduler.pending();
            return result.map(
              (pending) => pending.isEmpty
                  ? 'nothing pending'
                  : pending.map((p) => 'id ${p.id}').join(', '),
            );
          },
        ),
        ActionRow(
          label: 'Cancel all',
          icon: Icons.cancel,
          isDestructive: true,
          run: scheduler.cancelAll,
        ),
      ],
    );
  }
}

/// Storage: what the kit wrote, beside the legacy key it adopted from.
class DevStoragePage extends StatefulWidget {
  /// Creates the page.
  const DevStoragePage({required this.store, required this.groups, super.key});

  /// The store to read.
  final KeyValueStore store;

  /// Which keys to read.
  final List<DevStorageGroup> groups;

  @override
  State<DevStoragePage> createState() => _DevStoragePageState();
}

class _DevStoragePageState extends State<DevStoragePage> {
  final Map<String, String> _values = <String, String>{};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Reads each key as several types, because the store is typed per call and
  /// the inspector does not know which one a key used.
  Future<String> _read(String key) async {
    final asString = await widget.store.getString(key);
    final string = asString.fold(onSuccess: (v) => v, onFailure: (_) => null);
    if (string != null) return string;

    final asInt = await widget.store.getInt(key);
    final integer = asInt.fold(onSuccess: (v) => v, onFailure: (_) => null);
    if (integer != null) return '$integer';

    final asBool = await widget.store.getBool(key);
    final boolean = asBool.fold(onSuccess: (v) => v, onFailure: (_) => null);
    if (boolean != null) return '$boolean';

    final asList = await widget.store.getStringList(key);
    final list = asList.fold(onSuccess: (v) => v, onFailure: (_) => null);
    if (list != null) return '${list.length} entries';

    return '—';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    for (final group in widget.groups) {
      for (final entry in group.entries) {
        _values[entry.key] = await _read(entry.key);
        final legacy = entry.legacyKey;
        if (legacy != null) _values[legacy] = await _read(legacy);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage'),
        actions: <Widget>[
          IconButton(
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: <Widget>[
          const DevNote(
            'A namespaced key beside the legacy key it adopted from. Matching '
            'values mean the migration carried real data over.',
          ),
          for (final group in widget.groups) ...<Widget>[
            DevHeading(group.title),
            for (final entry in group.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SelectableText(
                      '${entry.key}\n  = ${_values[entry.key] ?? "…"}',
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 11),
                    ),
                    if (entry.legacyKey != null)
                      SelectableText(
                        'legacy ${entry.legacyKey}\n  = '
                        '${_values[entry.legacyKey!] ?? "…"}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    const Divider(height: 12),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

extension _EmptyFallback on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
