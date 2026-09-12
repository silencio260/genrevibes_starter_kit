# Changelog

## 0.1.0-dev.1

- Add `AppodealNativeAdView`, which renders one loaded Appodeal native ad in the
  SDK's Android `NativeAdView`, laid out by `AppodealNativeAdStyle` (medium with
  media, or small without), and follows the provider's gating.
- Add `AppodealNativeAds`, which forwards Appodeal's app-wide native callbacks
  and maps them to neutral `AdEvent`s for a placement.
