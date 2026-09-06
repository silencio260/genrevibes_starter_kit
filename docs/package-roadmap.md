# Package roadmap

## Foundation milestone

- [x] Archive the pre-modular monolith to `deprecated_old_version_1/` under the
  name `genrevibes_starter_kit_legacy`, leaving the repository root as a plain
  workspace with no package of its own.

- [x] Record the modular architecture and dependency rules.
- [x] Create `genrevibes_core`.
- [x] Create the provider-neutral `genrevibes_iap` contract.
- [x] Extract RevenueCat configuration, products, purchases, identity,
  restore, and entitlement behavior into `genrevibes_iap_revenuecat`.
- [x] Extract hosted paywall and customer-center presentation into the
  optional `genrevibes_iap_revenuecat_ui` adapter.
- [x] Add an IAP provider contract-test harness.
- [x] Add a RevenueCat composition example without committed SDK keys.
- [ ] Build a RevenueCat example on Android and iOS.

## Proven-provider milestone

- [x] Create the provider-neutral analytics contract and consent-aware,
  failure-isolated multi-sink pipeline.
- [x] Add a shared analytics sink contract-test harness.
- [x] Extract the Firebase Analytics adapter without coupling Crashlytics.
- [x] Extract the PostHog adapter with privacy-first session replay defaults.
- [x] Extract the Mixpanel events adapter.
- [x] Isolate Mixpanel session replay behind a separately installable package.
- [x] Create provider-neutral remote-config contracts and typed value handling.
- [x] Add Firebase Remote Config and optional SharedPreferences cache adapters.
- [x] Create provider-neutral ads contracts, shared provider tests, premium/
  suppression/frequency policy, and the AdMob full-screen adapter.
- [x] Extract lifecycle-safe AdMob banner and native presentation APIs.
- [x] Create notification contract and OneSignal adapter.
- [x] Create local-notification scheduling adapter.
- [x] Add the thin `genrevibes_starter_kit` coordinator.

## Capability milestone

- [x] Create `genrevibes_storage` with a neutral key-value contract, an
  in-memory implementation, and legacy-key adoption so adopting a capability
  never resets state an app already persisted.
- [x] Add the optional `genrevibes_storage_shared_preferences` implementation.
- [x] Create `genrevibes_consent` with a neutral consent state machine and a
  gate that ads and analytics initialization can await.
- [x] Add the Google UMP consent adapter. Each ad network ships its own.
- [x] Create `genrevibes_app_rating` with a clock-driven eligibility engine and
  provider-neutral outcome routing.
- [x] Add the `in_app_review` store adapter and the FeedbackNest rating adapter.
- [x] Create `genrevibes_feedback` with submission and attachment contracts.
- [x] Add the FeedbackNest feedback adapter.
- [x] Create `genrevibes_onboarding` with completion state and optional
  presentation templates.
- [x] Create `genrevibes_settings` with reusable models and embeddable UI.

## Story Saver baseline milestone

- [x] Create `genrevibes_crash` with a neutral reporter contract, coordinator,
  contract harness, and the Crashlytics adapter with framework hooks.
- [x] Create `genrevibes_engagement` (retention + user targeting).
- [x] Create `genrevibes_remote_policy` (ads policy schema, analytics names).
- [ ] Create `genrevibes_permissions` and the `permission_handler` adapter.
- [ ] Create `genrevibes_device_identity`.
- [ ] Create `genrevibes_app_links` and the launcher adapter.
- [ ] Create `genrevibes_auth` / `genrevibes_database` contracts and Firebase
  adapters (consumers: ai_chatbot, note_ai; never Story Saver).

## Production-hardening milestone

- [ ] Test the minimum supported and current stable Flutter versions. The
  exact-version CI matrix is implemented; Flutter 3.44.1 passes locally, and
  the first hosted matrix run remains outstanding.
- [x] Add an Android/iOS release-build smoke app containing every native
  provider adapter. Android release is locally verified; iOS CocoaPods
  resolution passes, while the local Xcode platform installation must be
  repaired before its device compile can be called verified.
- [ ] Add contract, unit, widget, integration, and lifecycle tests.
- [x] Add dependency-boundary and accidental-vendor-import checks.
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
