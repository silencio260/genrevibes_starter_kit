# genrevibes_ads_yodo1

Yodo1 MAS mediation adapter for the GenRevibes ads contract, built on the
official `yodo1_mas_flutter_plugin`.

MAS is a managed waterfall. Networks, bidding, banner position and test
devices are configured in the MAS dashboard; the SDK exposes only `initSdk`,
`loadAd`, `isAdLoaded`, `showAd` and one callback per format. The adapter maps
that onto `AdProvider`, and four consequences are worth knowing before
designing a placement around it.

**One inventory slot per format.** MAS has no per-unit identity, so every
placement of the same format shares one loaded creative. `AdPlacement.id` is
carried into `events` and passed to the SDK as its optional placement id for
reporting, but it does not create separate inventory. Per-placement pacing
therefore has to come from `AdPolicyController`, not from the provider.

**Banner and native are native overlays, not Flutter widgets.** The plugin
ships no platform view, so there is no equivalent of `AdMobBannerView`. The
SDK draws them over the whole app at the dashboard position; they cannot be
placed in a Flutter layout, measured, or have space reserved for them.

**A shown banner cannot be hidden.** There is no dismiss or hide call. Once
`show` displays a banner or native overlay it stays until the SDK replaces or
removes it. An app with a surface that must be clean — a secure screen, a
camera view, a video player — cannot rely on this adapter to clear one.

**No impression revenue.** MAS reports no paid callback through the plugin, so
`events` never carries `AdEventType.paid`. Revenue comes from the MAS
dashboard, not from client analytics, and `ad_impression` cannot be enriched
with a value.

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

The plugin declares the mediation networks' maven repositories itself and
requires `minSdk` 24. An app whose Gradle setup forbids module-level
repositories (`RepositoriesMode.FAIL_ON_PROJECT_REPOS`) has to declare those
repositories centrally instead.
