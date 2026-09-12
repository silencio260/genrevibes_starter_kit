# Changelog

## 0.1.0-dev.2

- Log every revenue report: amount, currency, network, format, placement and
  precision, or a warning when no configured placement matches it. Appodeal
  reports revenue only when the winning network's adapter does, and never for
  test ads, so the log is how a release build confirms revenue is arriving.

## 0.1.0-dev.1

- Add `AppodealAdProvider` for interstitial and rewarded placements over
  `stack_appodeal_flutter` 4.x, with loaded, impression, click, dismissal, and
  impression-level revenue events.
- Add `AppodealBannerView`, which follows the provider's health.
- `AppodealAdProvider` implements `AdTestModeProvider`. The mode applies when
  the SDK initializes; a later change withholds inventory until relaunch.
- Add the injectable `AppodealClient` boundary.
- Initialization fails only on a critical SDK error or when no ad type
  initialized. Internal errors, such as `SdkConfigurationError` on an app with
  no analytics services configured, are kept as warnings in health.
