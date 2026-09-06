# genrevibes_ads_admob_ui

Optional banner and Google native-template widgets for the AdMob adapter.

Eligibility is an explicit application input:

```dart
AdMobBannerView(
  request: bannerRequest,
  enabled: !isPremium && !adsSuppressed && remoteConfigAllowsBanner,
  onEvent: analytics.recordAdEvent,
)
```

Changing `enabled` to false disposes loaded inventory. A generation guard also
disposes any ad whose asynchronous load completes after the widget was disabled,
reconfigured, or removed. The package has no BLoC, GetIt, IAP, analytics, or
remote-config dependency.

Initialize `AdMobAdProvider` before mounting these widgets so Google Mobile Ads
and any test-device configuration are ready.
