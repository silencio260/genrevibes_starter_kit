# genrevibes_exit_prompt

What Android Back does on a GenRevibes app's root screen. The style is chosen
at runtime, normally from remote config, so it can be A/B tested without a
release. The package knows nothing about ads: an ad is a builder and the height
the prompt keeps for it.

## Styles

| `wireName` | Shows | Needs |
|---|---|---|
| `ad_sheet` | Bottom sheet: native ad above a full-width Exit bar | `ad` |
| `ad_dialog` | Dialog: title, native ad, Exit and Cancel | `ad` |
| `features_sheet` | Tall sheet: feature carousel, native ad when given, the exit question, Exit and Cancel | `features` |
| `offer_sheet` | Sheet: one offer, such as premium, with Exit under it | `offer` |
| `confirm_dialog` | Dialog: title, message, Exit and Cancel | — |
| `double_tap` | A hint on the first Back, exit on a second within `doubleTapWindow` | — |
| `none` | Back closes the app | — |

A style missing what it needs shows `fallbackStyle` (default `confirm_dialog`)
— for a premium user without an ad, say.

## Composition

```dart
ExitGuard(
  config: (context) => ExitPromptConfig(
    style: ExitPromptStyle.tryParse(remote.read(ExitPromptPolicyKeys.style)) ??
        ExitPromptStyle.featuresSheet,
    exitButton: ExitButtonEmphasis.tryParse(
          remote.read(ExitPromptPolicyKeys.exitButton),
        ) ??
        ExitButtonEmphasis.standard,
    ad: isPremium
        ? null
        : ExitPromptAd(
            height: adStyle.resolvedHeight,
            builder: (_) => AppodealNativeAdView(
              provider: ads,
              placement: AppPlacements.exitNative,
              enabled: true,
              style: adStyle,
              placeholder: const AppodealNativeAdPlaceholder(style: adStyle),
              preloadNext: true,
            ),
          ),
    features: [
      ExitPromptFeature(id: 'gallery', title: 'Saved gallery', onSelected: openGallery),
    ],
    theme: const ExitPromptTheme(accentColor: brand),
  ),
  onShown: (style) => analytics.track('exit_prompt_shown', {'style': style.wireName}),
  onResult: (result) => analytics.track('exit_prompt_action', {
    'style': result.style.wireName,
    'action': result.action.name,
  }),
  child: Scaffold(/* the root screen */),
);
```

## Behavior

- **Only the guarded route.** Back on any screen above it pops as usual.
- **Built per press.** `config` runs on every Back, so premium, remote config
  and ad eligibility are current.
- **Results.** Dismissing a sheet or dialog is `stay`. `feature` and `offer`
  run their callback with the guard's context after the prompt closes. `exit`
  calls `onExit`, which defaults to `SystemNavigator.pop`.
- **Ad space is kept** at `ExitPromptAd.height`, so the prompt does not move
  when the ad loads. Preload the ad before Back is pressed, or the first prompt
  shows the placeholder.
- **Exit button.** `standard` is readable like any secondary button; `dimmed`
  is muted grey, still labeled and working.

## Ad policy

Google Play's ads policy lists as disruptive "Ads that are triggered by the
home button or other features explicitly designed for exiting the app". Back
on the root screen is how a user exits, so a prompt with an ad is exposed to
that whichever network serves the ad, and the risk falls on the developer
account. The portfolio default is `features_sheet` without an ad; the ad styles
are for deliberate tests.

AdMob asks publishers to "take extreme care when using AdMob ads in cases
where your users might be more prone to accidental clicks". A user closing an
app taps fast, and an Exit button styled to look unavailable steers taps to
the ad. Networks treat clicks that do not convert as invalid traffic. Watch the
click-through and conversion of any `dimmed` test.

## September hardening

Align the Dart minimum with the existing Flutter 3.27 requirement.

See [portfolio adoption](../../../docs/portfolio-adoption.md) and
[implementation/check status](../../../docs/production-hardening-plan.md).
