# Changelog

## 0.1.0-dev.2

- `AppodealNativeAdView.preloadNext` loads the next native ad as soon as a view
  shows one, so the next view — such as the next ad page of an onboarding flow
  that alternates pages with and without an ad — appears without waiting.
- Add `AppodealNativeAdPlaceholder`, a text-free, untappable stand-in with the
  ad's size and colors, so a screen can keep the ad's space before it loads
  and nothing moves when it arrives.

## 0.1.0-dev.1

- Add `AppodealNativeAdView`, which renders one loaded Appodeal native ad in the
  SDK's Android `NativeAdView`, laid out by `AppodealNativeAdStyle` (medium with
  media, or small without), and follows the provider's gating.
- Add `AppodealNativeAds`, which forwards Appodeal's app-wide native callbacks
  and maps them to neutral `AdEvent`s for a placement.
