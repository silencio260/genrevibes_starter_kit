# Package roadmap

## Foundation milestone

- [x] Record the modular architecture and dependency rules.
- [x] Create `genrevibes_core`.
- [x] Create the provider-neutral `genrevibes_iap` contract.
- [x] Extract RevenueCat configuration, products, purchases, identity,
  restore, and entitlement behavior into `genrevibes_iap_revenuecat`.
- [ ] Extract hosted paywall and customer-center presentation into the
  optional `genrevibes_iap_revenuecat_ui` adapter.
- [ ] Add an IAP provider contract-test harness.
- [ ] Build a RevenueCat example on Android and iOS.

## Proven-provider milestone

- [ ] Create analytics contract, pipeline, and Firebase/PostHog adapters.
- [ ] Create remote-config contract and Firebase adapter.
- [ ] Create ads contract, policy layer, and AdMob adapter.
- [ ] Create notification contract and OneSignal adapter.
- [ ] Create local-notification scheduling adapter.
- [ ] Add the thin `genrevibes_starter_kit` coordinator.

## Production-hardening milestone

- [ ] Test the minimum supported and current stable Flutter versions.
- [ ] Add Android and iOS release-build examples.
- [ ] Add contract, unit, widget, integration, and lifecycle tests.
- [ ] Add dependency-boundary and accidental-vendor-import checks.
- [ ] Add changelogs, examples, API docs, repository metadata, and a license.
- [ ] Decide and verify the final pub.dev package names.
- [ ] Configure package-specific automated publishing.

## Portfolio migration milestone

- [ ] Migrate Story Saver analytics and remote config.
- [ ] Migrate notifications.
- [ ] Migrate ads and premium suppression.
- [ ] Migrate RevenueCat IAP and validate purchases/restores.
- [ ] Migrate reusable rating, feedback, consent, and onboarding behavior.
- [ ] Remove replaced app implementations and unused dependencies.

## Expansion milestone

- [ ] Add Adapty after RevenueCat contract parity is proven.
- [ ] Add Appodeal after the AdMob policy boundary is proven.
- [ ] Add CAS.AI and Yodo1 MAS through the same ads contract.
- [ ] Add an entitlement backend only when cross-provider migration or webhook
  reconciliation requires it.

## Release gates

A package is not production-ready until it has:

- No unintended vendor dependencies.
- Public API documentation and an executable example.
- Passing formatter, analyzer, and tests.
- Passing contract tests for provider adapters.
- A verified native release build where applicable.
- Tested initialization, error, offline, lifecycle, and disposal behavior.
- A changelog, license, semantic version, and successful publish dry run.
