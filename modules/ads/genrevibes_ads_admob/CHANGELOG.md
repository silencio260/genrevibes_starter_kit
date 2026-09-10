# Changelog

## 0.1.0-dev.3

- `AdMobAdProvider` implements `AdTestModeProvider`: `testMode` at construction
  and `setTestMode` at runtime move requests between the configured units and
  Google's sample units, discarding inventory loaded in the other mode.
- Add `AdMobAdProvider.servedUnitFor`, the unit a request goes to right now.

## 0.1.0-dev.2

- Add `AdMobTestAds`: Google's sample app IDs and ad units for Android and iOS.
- Add `AdMobAdUnit.withTestUnitId` and
  `GenRevibesAdMobConfiguration.withTestAdUnits`, so a development build can
  serve sample ads through the same placements without touching call sites.

## 0.1.0-dev.1

- Add AdMob interstitial, rewarded, and app-open provider support.
- Add impression-level revenue and click lifecycle events.
- Support one adapter API range from Google Mobile Ads 5.3.1 through 9.x;
  minimum-version contract tests remain pinned to 5.3.1.
