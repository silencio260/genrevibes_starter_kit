# genrevibes_ads_admob

Google Mobile Ads implementation for interstitial, rewarded, and app-open
placements. Provider ad-unit IDs are mapped to stable logical placements in
application-owned configuration. Paid, impression, click, and dismissal events
are emitted through the neutral `AdEvent` stream.

Banner and native-template presentation lives in the separately installable
`genrevibes_ads_admob_ui` package so headless/full-screen consumers do not
resolve Flutter widget APIs they do not use.

## Test ads

Every build that is not going to the store must request Google's sample units,
never the app's own. Requesting a real unit from a development build is invalid
traffic under the AdMob program policies, and a suspended or unapproved account
serves nothing to real units — sample units are not tied to any account and
fill regardless.

```dart
final configuration = GenRevibesAdMobConfiguration(adUnits: units);
final served = isDevelopment ? configuration.withTestAdUnits() : configuration;

// Inline units, for genrevibes_ads_admob_ui:
final banner = isDevelopment ? bannerUnit.withTestUnitId() : bannerUnit;
```

Pair sample units with Google's sample app ID in the native config for the same
builds (`AdMobTestAds.androidAppId` / `AdMobTestAds.iosAppId`). Banners map to
the fixed-size sample unit, which matches the default `AdSize.banner`.
