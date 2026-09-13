# Changelog

## 0.1.0-dev.4

- `AppodealNativeAdView` recreates its Android view when its style changes,
  such as a screen switching between a large and a small card. The Android
  view reads its style only at creation, so it used to keep the old layout
  inside the new size. The recreated view takes the next loaded ad.
- Add `AppodealNativeAdLayout.compact`: one row with the icon, the
  attribution badge and headline above one line of body, and the call to
  action at the end. No media and no top strip, for bottom-of-screen natives
  that replace banners. `resolvedHeight` and the placeholder support it.
- The attribution badge and AdChoices sit in their own strip at the top of the
  card (`AppodealNativeAdStyle.attributionStripHeight`, default 20) instead of
  over its corners, where the badge covered the icon and AdChoices could cover
  the headline. `resolvedHeight` and the placeholder include the strip, so
  views sized from them grow by the strip and one spacing.

## 0.1.0-dev.3

- Add `AppodealNativeAds.attributedAdEvents`, which attributes each app-wide
  native callback to the placement whose view asked for or took the ad. An app
  with more than one native placement listens once with it; an `adEvents`
  listener per placement reported every callback once per listener.

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
