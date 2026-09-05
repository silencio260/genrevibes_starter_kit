# GenreVibes packages

This directory contains the new modular package family. The original package
under the repository-level `lib/` directory remains a migration reference and
must not be imported by these packages.

Packages are intentionally standalone rather than members of a native Pub
workspace so their SDK lower bounds can remain below Dart 3.6. A package that
depends on another local GenreVibes package declares the future hosted
dependency in `pubspec.yaml` and uses `pubspec_overrides.yaml` for local
development. The override must never be copied into an application's published
dependency contract.

All new packages remain `publish_to: none` until names, ownership, licensing,
documentation, examples, and release automation have been approved.

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
