# Changelog

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
