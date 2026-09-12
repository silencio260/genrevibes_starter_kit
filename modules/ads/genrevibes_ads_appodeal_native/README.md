# genrevibes_ads_appodeal_native

Appodeal native ads for GenRevibes apps. Appodeal's Flutter plugin initializes
and caches native inventory but gives Flutter no way to render a native ad or
hear its callbacks. This package's Android plugin does both, using the SDK that
plugin already ships: a loaded ad is laid out in Appodeal's own `NativeAdView`,
which is what reports impressions and clicks to the SDK.

Everything else stays with `genrevibes_ads_appodeal`: initialization, test mode,
consent and ad gating, and caching. Configure a native placement there, and the
SDK initializes the native ad type with the rest.

## Composition

```dart
const onboardingNative =
    AdPlacement(id: 'onboarding_native', format: AdFormat.native);

final ads = AppodealAdProvider(
  configuration: GenRevibesAppodealConfiguration(
    appKey: appodealAppKey,
    placements: const <AppodealPlacement>[
      AppodealPlacement(placement: onboardingNative),
    ],
  ),
);

// Wherever the app wants a native ad:
AppodealNativeAdView(
  provider: ads,
  placement: onboardingNative,
  enabled: !isPremium,
  style: const AppodealNativeAdStyle(
    layout: AppodealNativeAdLayout.medium,
    callToActionColor: Color(0xFF7B4FE0),
  ),
);

// Native callbacks, as neutral events, for analytics:
AppodealNativeAds.instance.adEvents(onboardingNative).listen(trackAdEvent);
```

## Behavior

- **Gating.** The view renders its `placeholder` (nothing by default) while
  `enabled` is false or the provider does not serve inventory: before the SDK
  initializes, while `canRequestAds` says no, and after a test-mode change that
  waits for a relaunch.
- **Loading.** When no native ad is loaded, the view asks the provider to load
  one and appears on the next native load. Auto-cache is off for native ads,
  so nothing loads for a user who never reaches a native placement.
- **One ad per view.** A view takes one ad out of the SDK's cache and destroys
  it when disposed. Keep the same view on screen across page changes to show
  one ad; build a new one to show another.
- **Revenue** arrives on the provider's event stream, attributed to the native
  placement, like every other format.
- **Layout.** `AppodealNativeAdStyle` sets colors, sizes, corner radii and the
  attribution label, and whether the media view is shown. The Flutter view is
  sized to `AppodealNativeAdStyle.resolvedHeight`.

Android only. On other platforms the view renders its placeholder and no events
are reported.
