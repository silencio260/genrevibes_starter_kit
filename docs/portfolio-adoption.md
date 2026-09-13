# Reusing the starter kit in another app

The shared code lives in `modules/<capability>/<package>`. Add only the packages
listed for the features you want. Pin the kit submodule to a reviewed commit and
add path overrides for its transitive GenRevibes dependencies, as Story Saver
and the smoke example do. A submodule branch name is not a release version.

The snippets below belong in an app's composition or UI code. Variables such as
`store`, `context` and `feedback` are the instances your app creates; do not create
a second provider just to open a developer page.

## Startup and consent

Use `genrevibes_core` and `genrevibes_starter_kit`. Create a `KitResourceScope`,
register app listeners with `scope.add(subscription.cancel)`, and register
modules with `scope.addModule(module)` before awaiting initialization. Close the
scope if composition fails and when the runtime is replaced. Cleanup continues
when one callback throws or times out. Module disposal must be idempotent: both
the coordinator and the composition scope may release it.

```dart
final kit = GenRevibesStarterKit(
  autoStartDeferred: false,
  modules: [
    StarterModuleRegistration.deferred(
      moduleId: 'consent', create: () => consent,
      timeout: const Duration(seconds: 8),
    ),
    StarterModuleRegistration.deferred(moduleId: 'ads', create: () => ads),
  ],
);
await kit.initialize();
// From a mounted widget, after a frame is visible:
WidgetsBinding.instance.addPostFrameCallback((_) => kit.startDeferred());
```

For Appodeal add `genrevibes_consent`, `genrevibes_consent_appodeal` and
`genrevibes_ads_appodeal`. Supply the platform app key and use the same eight-second
budget on the gate and consent provider. The SDK decides who needs a form. A
failure or timeout releases the sequence without changing consent to “granted”
or “not required.” Do not add a second application gate on `canRequestAds` if
you want this continue-on-error policy. The SDK still uses its real consent
signals and controls available inventory. Native UI cannot be forcibly dismissed
by a Dart timeout, and ad display itself cannot be guaranteed.

Keep essential modules required; make optional integrations optional. Story
Saver renders loading/retry before Firebase starts, starts consent after the
main app renders, and uses a fresh resource scope for a failed launch retry.

## Developer section, Kit Lab and control

Add `genrevibes_developer_access` and `genrevibes_devtools`. Keep the default
controller, lockout, device lists, hidden gesture and Lab. Apps configure them:

```dart
final access = DeveloperAccessController(
  store: store,
  config: DeveloperAccessConfig(
    isDevelopmentBuild: kDebugMode,
    // Omit these options to retain the kit defaults.
    passcodeActions: {DeveloperAction.diagnostics},
  ),
);
```

`enabled: false` opts out entirely. `allowPasscode: false` disables the passcode
entry but retains listed developer phones. `passcode` overrides the shared
fallback; `actions` restricts all grants and `passcodeActions` can further limit
passcode sessions. Defaults still permit diagnostics and premium simulation.
`access.allows(DeveloperAction.premiumSimulation)` is the shared check; do not
write another unlock mechanism in each app. `lockSession()` ends a passcode
grant without removing a listed phone.

Pass the same module instances into `DevToolsHost`, including local notifications,
rating and onboarding. `StarterKitLabScreen(host: host)` checks developer access
on its hub and pushed pages. Set `requireDeveloperAccess: false` only when your
app deliberately supplies its own guard. An absent instance means “not
connected”; the Modules page shows disabled, waiting, ready, degraded and failed
states separately, including coordinator timeouts.

Create one `RecordingKitLogger` and pass it to the coordinator and providers as
well as `DevToolsHost.logger`. Pass one `RecordingDeliveryObserver` to the
analytics pipeline and `DevToolsHost.eventLog`. Story Saver retains these buffers
only in development builds. A listed device in a store build can open the Lab
but has no recorded log/event history. Live health and explicit actions remain
available. Logs can contain provider errors: do not log passcodes or form text.

For shared controls, add `genrevibes_remote_config`, your selected adapter and
`genrevibes_remote_policy`. Build a schema once; give that schema to the provider,
coordinator and Lab. Supply app keys, provider credentials and rollout choices.
Own/dispose the policy binders with the runtime.

## Subscriptions and ads

Add `genrevibes_iap`, `genrevibes_iap_revenuecat`, and optionally
`genrevibes_iap_revenuecat_ui`. Supply platform SDK keys, store products and exact
entitlement IDs. Use the existing shared rule engine:

```dart
final accessPolicy = EntitlementAccessPolicy([
  FeatureEntitlementRule(featureId: 'remove_ads', anyOf: {'ad_free', 'Pro'}),
  FeatureEntitlementRule(featureId: 'exports', anyOf: {'Pro'}),
]);
final removesAds = accessPolicy.isUnlocked('remove_ads', snapshot);
```

Keep one authoritative entitlement snapshot and follow `entitlementChanges`.
Keep developer simulation separate from real purchases and consult developer
action access each time. Story Saver defaults to entitlement `Pro`; override it
with `premium_entitlement_id`. Cancellation and pending payment are distinct
outcomes; a failed restore is an error. Do not report zero USD as purchase revenue.
The app now emits `purchase_completed` without an invented amount.

Pass your product's ad eligibility into every placement and the provider. Add
`genrevibes_ads_appodeal_native` only if using its native views; those views are
Android-specific. An unsupported placement returns an unsupported result.
Keep the same developer format switches and premium gate on banners, native,
splash, interstitial and exit placements. A consent failure does not replace
subscription, placement or developer-switch rules.

## Feedback/contact forms and settings

Add `genrevibes_feedback`, `genrevibes_feedback_ui` and your provider adapter
(`genrevibes_feedbacknest` in Story Saver). Supply credentials, labels, colors
and optionally a screenshot picker. Do not copy the form implementation.

```dart
await openFeedbackPage(context,
  provider: feedback,
  kind: FeedbackKind.contact,
  maxScreenshots: 1,
  maxAttachmentBytes: 10 * 1024 * 1024,
  submissionTimeout: const Duration(seconds: 30),
);
```

Timeout leaves the text and attachments in place, releases the busy state and
allows retry/back. It means delivery is unconfirmed; a manual retry can duplicate
a message already received by the server. Concurrent taps cannot start two
submissions or exceed the attachment count. The FeedbackNest adapter caps each
attachment at 10 MB and cleans its temporary files after the request settles.
It explicitly rejects nonempty metadata because its current SDK does not accept
that field. Choose another provider if your app needs metadata.

For apps using PostHog, pass `protectContent: (child) =>
PostHogMaskWidget(child: child)` to `openFeedbackPage` and `DeveloperUnlockGesture`.
The mask widget is exported by `genrevibes_analytics_posthog`; neutral form and
developer packages do not import that SDK. Story Saver masks both complete routes.

Add `genrevibes_settings` for `SettingsList`, `SettingsTile`, `SettingsAction`,
`SettingsToggle` and `SettingsInfo`. Supply your sections, callbacks and state;
the kit renders the common rows inside your existing screen or tab. Add
`genrevibes_app_links` and `genrevibes_app_links_launcher` for share/store/support
links. Configure both store URLs where both platforms ship. Story Saver's iOS
store URL comes from `app_store_url`; a missing link returns a configuration error.

These are reusable feedback/contact forms, not a general-purpose form designer.
Other forms can use Flutter's form controls until a second shared form justifies
extracting more machinery.

## Permissions and notifications

Add `genrevibes_permissions`, `genrevibes_permissions_handler` and storage.
Use `PermissionCoordinator(provider: provider, store: store)` for the shared
check/request/recheck sequence, persisted throttling and `needsSettings` outcome.
Supply purpose-specific copy and platform declarations. Request only after a user
action. On app resume, call `check`, not `request`, to detect changes made in
phone settings without prompting again. Story Saver now does this on Home.
Its WhatsApp folder access remains app-owned; it is not a generic gallery grant.

For local notifications add `genrevibes_notifications` and
`genrevibes_notifications_local`. For remote push optionally add
`genrevibes_notifications_onesignal`. Supply platform setup, channel IDs, icon,
permission rationale, a real IANA timezone and your app's destination mapping.

A `LocalNotificationPendingInteractions` scheduler retains the most recent tap
until navigation calls `takePendingInteraction()`. Subscribe to `interactions`
for live taps and drain once after your destination routes are ready. Analytics
must not consume the tap. Story Saver routes auto-save notices to Saved after
normal splash/onboarding, including notices from older versions with ID 0.

On resume, resolve the current timezone and call `updateTimeZone` through
`LocalNotificationTimeZoneUpdater`. The local adapter updates future schedules
and re-schedules daily requests created in this process. Persisted campaign
definitions remain the host/source's responsibility: refresh them at every cold
start. `NotificationCampaignCoordinator.managedIds` limits cancellations to
that campaign's IDs; use separate sets for separate features. Do not call
`cancelAll()` to turn off a single campaign. Story Saver currently posts immediate
auto-save notices, not scheduled campaigns.

## Recording defaults and upgrades

New `PortfolioRemoteConfigSchema.build()` defaults use zero replay rollout and
masked text/images. Existing apps that want their old choices must pass
`replayDefaults: SessionReplayPolicy(...)` explicitly. Story Saver explicitly
keeps 100% and its existing global masking settings; the sensitive routes above
are masked independently. Activated remote values still take precedence.

Configure the SDK from `controller.plan`, then attach the recorder with that
same `configuredPlan`. Lab distinguishes requested recording from the last
successful SDK command and from an explicit SDK status query. Mask changes show
“restart required”; stricter requested masking stops recording until restart.
The remote master switch also wins over a local force-on override.

Keep namespaced storage keys and use `MigratingKeyValueStore` with legacy mappings
rather than clearing preferences. This change preserves onboarding, rating,
identity, rollout bucket, developer lists and saved developer switches. Confirm
these on an upgraded installation before releasing. See
[compatibility](compatibility-matrix.md) for declared toolchain requirements and
[implementation notes](production-hardening-plan.md) for checks still requiring
a device.
