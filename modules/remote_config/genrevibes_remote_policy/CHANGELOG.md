# Changelog

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
