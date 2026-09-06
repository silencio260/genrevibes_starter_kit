# GenRevibes packages

This directory contains the new modular package family. The original package
under the repository-level `lib/` directory remains a migration reference and
must not be imported by these packages.

Packages are intentionally standalone rather than members of a native Pub
workspace so their SDK lower bounds can remain below Dart 3.6. A package that
depends on another local GenRevibes package declares the future hosted
dependency in `pubspec.yaml` and uses `pubspec_overrides.yaml` for local
development. The override must never be copied into an application's published
dependency contract.

All new packages remain `publish_to: none` until names, ownership, licensing,
documentation, examples, and release automation have been approved.

Run `bash tool/check_packages.sh` from the repository root to resolve every
independent package, verify formatting, analyze, test, and enforce vendor
dependency boundaries. `bash tool/verify_package_boundaries.sh` runs only the
fast architecture check.

## Current package family

- `genrevibes_core`: provider-neutral results, errors, lifecycle, diagnostics,
  clock, and logging boundaries.
- `genrevibes_iap`: provider-neutral IAP models, provider contract, and feature
  entitlement policy.
- `genrevibes_iap_test`: reusable behavioral contract tests for IAP adapters.
- `genrevibes_iap_revenuecat`: RevenueCat purchases and entitlements without a
  hosted-UI dependency.
- `genrevibes_iap_revenuecat_ui`: optional RevenueCat paywall and customer
  center integration.
- `genrevibes_analytics`: consent-aware analytics contracts and a multi-sink
  pipeline with per-provider failure isolation.
- `genrevibes_analytics_test`: reusable behavioral contract tests for
  analytics provider adapters.
- `genrevibes_analytics_firebase`: isolated Firebase Analytics sink. Firebase
  initialization remains the host application's responsibility.
- `genrevibes_analytics_posthog`: isolated PostHog sink with optional,
  privacy-masked session replay.
- `genrevibes_analytics_mixpanel`: isolated Mixpanel event sink that does not
  resolve the session-replay plugin.
- `genrevibes_analytics_mixpanel_replay`: optional privacy-masked replay
  lifecycle and widget integration. Its newer Flutter baseline cannot affect
  apps that only install the events adapter.
- `genrevibes_remote_config`: typed schemas, bundled defaults, validation,
  safe snapshots, and last-known-good coordination without a vendor SDK.
- `genrevibes_remote_config_firebase`: Firebase fetch, activation, and
  persisted-value adapter.
- `genrevibes_remote_config_shared_preferences`: optional cross-launch cache
  for validated snapshots.
- `genrevibes_ads`: logical placements, formats, rewards, provider events, and
  premium/suppression/frequency policy without an ad SDK.
- `genrevibes_ads_test`: reusable ad-provider lifecycle and inventory contract
  tests.
- `genrevibes_ads_admob`: isolated Google Mobile Ads adapter for interstitial,
  rewarded, and app-open placements.
- `genrevibes_ads_admob_ui`: optional lifecycle-safe banner and native-template
  widgets with explicit host-controlled eligibility.
- `genrevibes_notifications`: provider-neutral push state, safe delivery
  diagnostics, local schedules, and hardcoded/remote campaign coordination.
- `genrevibes_notifications_onesignal`: isolated OneSignal 5.x push adapter.
- `genrevibes_notifications_local`: optional persistent local scheduler pinned
  to the separately tested `flutter_local_notifications` 19.x toolchain.
- `genrevibes_starter_kit`: thin lazy lifecycle coordinator that depends only
  on core and never selects providers or a dependency-injection framework.
