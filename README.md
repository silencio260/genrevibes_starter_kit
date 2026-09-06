# GenRevibes Starter Kit

A modular Flutter package family for capabilities shared across the GenRevibes
app portfolio. Applications install only the contracts and provider adapters
they select; an unused vendor SDK is not resolved or compiled into the app.

The production package family lives in `packages/`. The pre-modular monolith is archived read-only in `deprecated_old_version_1/`
as a behavior and migration reference; nothing depends on it and the boundary
script fails if anything tries.

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
    path: ../genrevibes_starter_kit/packages/genrevibes_starter_kit
  genrevibes_iap_revenuecat:
    path: ../genrevibes_starter_kit/packages/genrevibes_iap_revenuecat
  genrevibes_notifications_onesignal:
    path: ../genrevibes_starter_kit/packages/genrevibes_notifications_onesignal
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
