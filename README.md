# GenRevibes Starter Kit

A modular Flutter package family for capabilities shared across the GenRevibes
app portfolio. Applications install only the contracts and provider adapters
they select; an unused vendor SDK is not resolved or compiled into the app.

The production package family lives in `packages/`. The pre-modular monolith is archived read-only in `deprecated_old_version_1/`
as a behavior and migration reference; nothing depends on it and the boundary
script fails if anything tries.

## Repository layout

Packages are grouped by capability under `modules/`. A capability's neutral
contract, its vendor adapters and its contract-test harness sit together,
because they are read and changed together.

```text
modules/<capability>/genrevibes_<package>
```

| folder | packages | contents |
|---|---|---|
| `ads/` | 4 | ads, ads_admob, ads_admob_ui, ads_test |
| `analytics/` | 6 | analytics, analytics_firebase, analytics_mixpanel, analytics_mixpanel_replay, analytics_posthog, analytics_test |
| `app_links/` | 2 | app_links, app_links_launcher |
| `app_rating/` | 3 | app_rating, app_rating_in_app_review, app_rating_test |
| `auth/` | 3 | auth, auth_firebase, auth_test |
| `consent/` | 3 | consent, consent_test, consent_ump |
| `crash/` | 3 | crash, crash_crashlytics, crash_test |
| `database/` | 3 | database, database_firestore, database_test |
| `device_identity/` | 2 | device_identity, device_identity_platform |
| `engagement/` | 1 | engagement |
| `feedback/` | 2 | feedback, feedbacknest |
| `foundation/` | 2 | core, starter_kit |
| `iap/` | 4 | iap, iap_revenuecat, iap_revenuecat_ui, iap_test |
| `notifications/` | 3 | notifications, notifications_local, notifications_onesignal |
| `onboarding/` | 1 | onboarding |
| `permissions/` | 2 | permissions, permissions_handler |
| `remote_config/` | 4 | remote_config, remote_config_firebase, remote_config_shared_preferences, remote_policy |
| `settings/` | 1 | settings |
| `storage/` | 2 | storage, storage_shared_preferences |

Package names are unchanged and independent of the folder: `genrevibes_ads_admob`
is imported as `package:genrevibes_ads_admob/...` wherever it lives. The folder
is navigation, not identity.

`foundation/` holds what capabilities are built on rather than a capability of
its own, and `remote_policy` sits with `remote_config/` because it is the schema
binding remote configuration to ads and analytics.

## Package model

```text
application
  -> genrevibes_starter_kit        optional lifecycle coordinator
  -> selected provider adapter     RevenueCat, AdMob, Firebase, etc.
       -> neutral capability       IAP, ads, analytics, etc.
            -> genrevibes_core
```

The neutral packages do not expose vendor types. A host can replace RevenueCat
with a future Adapty adapter, or AdMob with another mediation adapter, without
rewriting its entitlement, ad-policy, analytics, or notification behavior.

Current capabilities include:

- IAP contracts, RevenueCat, and optional RevenueCat UI.
- Ads contracts, policy, test harnesses, AdMob, and optional inline ad UI.
- Consent-aware multi-sink analytics with Firebase, PostHog, Mixpanel events,
  and separately installable Mixpanel Session Replay.
- Typed remote config with Firebase and optional SharedPreferences caching.
- Push contracts and OneSignal diagnostics.
- Persistent local notification campaigns with bundled or remotely supplied
  schedules.
- A provider-neutral, instance-based lifecycle coordinator.

## Consuming packages from this repository

Add only the packages the app uses. For example:

```yaml
dependencies:
  genrevibes_starter_kit:
    path: ../genrevibes_starter_kit/modules/foundation/genrevibes_starter_kit
  genrevibes_iap_revenuecat:
    path: ../genrevibes_starter_kit/modules/iap/genrevibes_iap_revenuecat
  genrevibes_notifications_onesignal:
    path: ../genrevibes_starter_kit/modules/notifications/genrevibes_notifications_onesignal
```

Until packages are published, local development also needs path overrides for
their neutral GenRevibes dependencies. Each package's committed
`pubspec_overrides.yaml` demonstrates that repository-local wiring. Published
apps will use normal semantic version constraints instead.

Provider selection happens in the application composition root. The thin
coordinator never imports or automatically selects a vendor, DI container, or
state-management library.

## Verification

Run the complete locally installed Flutter tier:

```sh
bash tool/test_compatibility_tier.sh current
```

Run the native provider-graph smoke app:

```sh
cd examples/genrevibes_smoke_app
flutter pub upgrade
flutter test
flutter build apk --release
flutter build ios --release --no-codesign
```

The CI matrix runs exact per-package Flutter floors plus current stable and
Android/iOS native release builds. A native compile proves dependency and
plugin-registration compatibility; real provider keys, dashboards, purchases,
ads, push delivery, permissions, and lifecycle behavior still require app-level
integration/device tests.

## Project documents

- [Architecture](docs/architecture.md)
- [Compatibility matrix](docs/compatibility-matrix.md)
- [Package roadmap](docs/package-roadmap.md)
- [Toolchain risk register](docs/toolchain-risks.md)
- [Notification migration notes](docs/notifications-migration.md)

The package names and license are deliberately not final until the pub.dev
release decision is made. Packages therefore remain `publish_to: none`.
