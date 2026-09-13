# Changelog

## Unreleased — 2026-09-13

- Make replay defaults configurable per app; new apps default to zero rollout and masked content.

## 0.1.0-dev.6

- Add `SplashAdPolicyKeys`: `splash_ad_format` (`interstitial`, `rewarded`,
  `app_open` or `none`; default `interstitial`), `splash_ad_max_wait_seconds`
  (default 8) and `splash_ad_on_first_launch` (default true), with
  `formatOf` mapping the format to an `AdFormat`.
- Add `ExitPromptPolicyKeys`: `exit_prompt_style` (default `features_sheet`,
  without an ad, because Google Play treats ads triggered by exiting the app
  as disruptive) and
  `exit_prompt_exit_button` (`standard` or `dimmed`; default `standard`).
- `PortfolioRemoteConfigSchema.build` includes both.

## 0.1.0-dev.5

- Add `OnboardingPolicyKeys.adsEnabled` (`onboarding_ads_enabled`, default
  true), a remote switch that permits ads in onboarding, and include it in
  `PortfolioRemoteConfigSchema.build`.

## 0.1.0-dev.4

- The canonical ad click event is `custom_ad_click`, not `ad_click`, which
  Firebase Analytics reserves: `firebase_analytics` throws on it, so it reached
  every sink except Firebase. The override key is still `event_ad_click`. A
  caller resolving `ad_click` gets no override.

## 0.1.0-dev.3

- Add `DeveloperAccessPolicyKeys` (`developer_device_hashes`, a JSON array of
  developer device hashes) and `DeveloperAccessRemotePolicyBinder`, so a phone
  gains or loses developer access and test ads without a release.
- Include the key in `PortfolioRemoteConfigSchema.build`.

## 0.1.0-dev.2

- Add `SessionReplayPolicyKeys` and `SessionReplayRemotePolicyBinder`, so the
  session-replay rollout percentage and masking flags move without a release.
- Include the replay keys in `PortfolioRemoteConfigSchema.build`.

## 0.1.0-dev.1

- Add `AdsPolicyKeys`, `AdsPolicyConfig`, `AdsRemotePolicyBinder`,
  `AnalyticsNamesSchema`, `RemoteAnalyticsEventNames`, and the portfolio schema.
