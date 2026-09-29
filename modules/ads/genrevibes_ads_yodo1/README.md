# genrevibes_ads_yodo1

Yodo1 MAS mediation adapter for the GenRevibes ads contract, built on the
official `yodo1_mas_flutter_plugin`.

MAS manages networks, bidding and test devices in its dashboard. Fullscreen
formats use the official plugin and share inventory per format. Placement IDs
are reporting/pacing identities, not network ad-unit IDs.

Fullscreen `load` calls coalesce per format and complete on a real loaded/failed
callback or a positive SDK readiness check, not merely method-channel submission.
A pending load has a 30-second deadline; a reported failure completes immediately.
The host owns retry scheduling and must recheck eligibility before each attempt.
The launcher waits two seconds after failure before retrying while foreground and
policy-eligible. Loading never automatically shows an ad. Dispose the runtime to
cancel its retry worker and the provider's outstanding load deadlines.

## Embedded Android ads and preloading

This package adds `Yodo1BannerView` and `Yodo1NativeView` using Android platform
views. Each owns its MAS view, fits the Flutter destination slot, forwards
load/failure/revenue callbacks, and destroys its creative on disposal. Inline
views are not supported on iOS by this bridge.

After provider startup and app eligibility checks, call
`Yodo1InlinePreloads.load(placement, ...)`. Native preloads require `widthPx`,
`heightPx` and the same background color as the destination; banners require
the matching size. No hidden platform view or window is mounted for preloading.
The matching widget takes ownership of the loaded **or in-flight** request;
it does not request a second creative. Mismatched slots load independently.

The Android cache holds up to six entries, expires unused entries after two
minutes, and abandons pending loads after 30 seconds. Activity detachment,
engine detachment or `Yodo1InlinePreloads.clear()` destroys unused inventory.
A mounted destination owns its own disposal instead. Cache-ready means the
SDK loaded inventory, not that a user saw it; layout/content verification runs
after native attachment. No cached click/revenue events are replayed.

Hosts must recheck premium, suppression, developer switches, placement policy,
provider health and foreground state before preload and display. Keep any
splash wait bounded separately; a splash timeout does not cancel a native
request. Failed or unavailable inventory must not block navigation. Preserve
the full slot dimensions while loading, rather than clipping a native card to
a fraction of its size. See the [MAS Android ad-format guide](https://developers.yodo1.com/docs/sdk/guides/android/ad-formats/).

## Consent

`GenRevibesYodo1Configuration.useMasPrivacyDialog` turns on MAS's own privacy
dialog, and the CCPA/COPPA/GDPR flags are passed to `initSdk`. This is the ad
network's consent form, which is the only consent surface in this portfolio;
it never gates product analytics or session replay.

## Test mode

MAS has no runtime test-mode API: test devices are registered in the MAS
dashboard. `AdTestModeProvider` is therefore not implemented, and a developer
phone cannot be switched to test inventory from inside the app.

## Android

Android initializes through the process-aware `genrevibes.ads.yodo1/control`
bridge. The client separately registers the official `com.yodo1.mas/sdk`
incoming ad-event handler before initialization: the vendor Dart plugin normally
installs that handler inside `initSdk`, which this Android path bypasses.
Loading and showing still use the official plugin. Without this handler, native
loaded/opened/closed events never reach the provider, and a show timeout leaves
fullscreen ads blocked as an unresolved presentation.

The plugin declares the mediation networks' maven repositories itself and
requires `minSdk` 24. An app whose Gradle setup forbids module-level
repositories (`RepositoriesMode.FAIL_ON_PROJECT_REPOS`) has to declare those
repositories centrally instead.
