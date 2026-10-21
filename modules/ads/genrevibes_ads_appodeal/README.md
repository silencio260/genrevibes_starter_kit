# genrevibes_ads_appodeal

Appodeal mediation implementation of the `AdProvider` contract declared by
`genrevibes_ads`. Interstitial and rewarded placements go through `load` and
`show`; banner placements are rendered by `AppodealBannerView`, and native
placements by `AppodealNativeAdView` from `genrevibes_ads_appodeal_native`,
which also reports native callbacks. Callbacks and
impression-level revenue from every mediated network arrive on the provider's
neutral `AdEvent` stream under the logical placement, with the network that
served as `AdRevenue.mediationNetwork`.

Pair it with `genrevibes_consent_appodeal`, which resolves consent through the
consent manager inside the same SDK.

## Composition

```dart
final ads = AppodealAdProvider(
  configuration: GenRevibesAppodealConfiguration(
    appKey: appodealAppKey, // Android and iOS keys differ
    placements: const <AppodealPlacement>[
      AppodealPlacement(placement: AppPlacements.banner),
      AppodealPlacement(placement: AppPlacements.interstitial),
    ],
  ),
  testMode: developerAccess.current.servesTestAds,
);

// Wherever the app wants a banner:
AppodealBannerView(
  provider: ads,
  placement: AppPlacements.banner,
  enabled: !isPremium,
);
```

Each placement maps to a dashboard placement name, `default` unless given.
Appodeal has no ad-unit IDs: inventory belongs to the app key and the ad type.

## Test mode

Appodeal documents test mode as set before the SDK initializes. `testMode` at
construction, or `setTestMode` before `initialize`, picks the mode the SDK
starts in.

A change after initialization is not sent to the SDK. The provider withholds
all inventory instead — nothing loads, nothing shows, and `AppodealBannerView`
renders nothing — until the app relaunches in the new mode. A phone recognised
as a developer device mid-session therefore sees no ads rather than a live one.
`servesInventory` and the health details `testMode` / `sdkTestMode` show which
state the provider is in.

## User id for server-to-server rewards

`AppodealAdProvider` implements `AdUserIdProvider`. Call `setUserId` with an
opaque account id (a Firebase Auth uid, never an email or name) once the user
is signed in, and `setUserId(null)` on sign-out. Appodeal sends that id back as
`user_id` in its encrypted server-to-server reward callback, so the backend can
credit the account that watched the ad:

```dart
await ads.setUserId(firebaseUser.uid); // after sign-in
await ads.setUserId(null);             // after sign-out
```

Appodeal's callback carries `data1` (the IV) and `data2` (the AES-256-CBC
ciphertext, keyed with SHA-256 of the dashboard encryption key). The decrypted
query string holds `user_id`, `amount`, `currency`, `impression_id`,
`timestamp` and `hash`, a SHA-1 of the first five fields. The backend checks the
hash and keeps `impression_id` unique. The callback URL and encryption key are
set per app in the Appodeal dashboard.

## Full-screen inventory

Auto-cache is off for interstitials and rewarded video, so nothing loads until
`load` is called and a premium user never requests an ad. Banners keep
auto-caching. Appodeal cannot drop a loaded full-screen ad: `discard` makes the
provider forget it, and the coordinator's premium policy keeps it off screen.

## Native setup, per app

The plugin brings Appodeal core and its IAB adapter only. The rest is the app's:

- **Android:** add the network adapters to `android/app/build.gradle` (the
  Appodeal Flutter plugin README lists the current set) and the repository
  `https://artifactory.appodeal.com/appodeal`. With the AdMob adapter, add
  `com.google.android.gms.ads.APPLICATION_ID` to the manifest. minSdk 24. The
  plugin merges a network security config that permits cleartext traffic,
  which ad networks need.
- **iOS:** add the Appodeal and Bidon CocoaPods sources and the adapter pods to
  the Podfile, and `GADApplicationIdentifier` and `SKAdNetworkItems` to
  `Info.plist`. iOS 13 or later.
