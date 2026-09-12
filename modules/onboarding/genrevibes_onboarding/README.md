# genrevibes_onboarding

Onboarding completion state plus an optional presentation template. The
completion flag is the genuinely portfolio-reusable part; content, wording,
imagery, and navigation stay with the application.

`OnboardingController` reads and writes a single completion flag through
`genrevibes_storage`. Wrap the store in a `MigratingKeyValueStore` seeded with
`OnboardingKeys.legacyKeys`, or adopting this package re-onboards every existing
user on the release that ships it.

Unreadable state is treated as "not yet onboarded". Showing onboarding a second
time is a far better failure than never showing it to a genuinely new user.

`OnboardingView` is theme-driven and embeddable. It renders no `Scaffold` and no
`AppBar`, so a host can place it in its own route, a sheet, or a dialog, and it
takes colors from the ambient `ThemeData` rather than a hardcoded palette.

Artwork is supplied as a `WidgetBuilder` rather than an asset path. An app that
uses Lottie passes a Lottie widget, one that uses images passes an `Image`, and
neither pays for the other's dependency. This package depends on no animation or
image library at all.

## OnboardingFlow

`OnboardingFlow` is the configurable flow, for apps that need more than
`OnboardingView`:

- **Any number of pages.** Each page can hide the ad with `showAd: false`.
- **An optional ad slot.** `OnboardingAdSlot` takes a builder, so onboarding
  stays ad-agnostic: pass `AppodealNativeAdView` from
  `genrevibes_ads_appodeal_native`, or anything else. It sits below or above the
  controls, and keeps one ad on screen across pages unless `oneAdPerPage`.
- **Finish and skip actions.** A list of `OnboardingAction`s run in order, each
  awaited: `markCompleted`, `navigate`, `when` for a conditional step, or any
  async function, such as opening a paywall. A failing action stops the
  sequence unless `continueOnError`; each can have a `timeout`.
- **Layout.** `OnboardingControlsLayout.row` (skip, dots, next),
  `stacked` (dots over a centered next, leaving the bottom for an ad) or
  `fullWidthButton`; `OnboardingFlowStyle` for colors, text styles, padding and
  transitions; `pageBuilder` and `controlsBuilder` to replace either entirely.

```dart
OnboardingFlow(
  pages: const <OnboardingPage>[/* as many as the app needs */],
  controlsLayout: OnboardingControlsLayout.stacked,
  adSlot: OnboardingAdSlot(
    builder: (context, page) => AppodealNativeAdView(
      provider: ads,
      placement: AppPlacements.onboardingNative,
      enabled: adsAllowed,
    ),
  ),
  finishActions: <OnboardingAction>[
    OnboardingAction(openPaywall, continueOnError: true,
        timeout: const Duration(seconds: 30)),
    OnboardingAction.markCompleted(onboardingController),
    OnboardingAction.navigate(Routes.home),
  ],
);
```
