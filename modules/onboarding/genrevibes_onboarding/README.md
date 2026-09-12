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

- **Every page a whole screen.** By default each page is a complete screen:
  its content, its own controls and, when it has one, its own ad, swiping in
  as a unit. A page without an ad is a different screen, laid out for the full
  screen, not an ad screen with its ad removed. With
  `layout: OnboardingScreenLayout.edgeToEdge` the artwork runs across the top
  edge to edge and takes the height the rest leaves: the top half on an ad
  screen, most of the screen without one, and `artworkFadeHeight` fades it
  into the page above the title. `immersive` puts the text and controls over
  full-bleed artwork instead.
  `OnboardingPresentation.sharedControls` keeps one set of controls and one ad
  area under the swiping content instead.
- **Any number of pages.** Each page can hide the ad with `showAd: false`.
- **An optional ad slot.** `OnboardingAdSlot` takes a builder, so onboarding
  stays ad-agnostic: pass `AppodealNativeAdView` from
  `genrevibes_ads_appodeal_native`, or anything else. It sits below or above the
  controls. Alternate `showAd` to put an ad screen between full-screen ones.
  Set `reservedHeight` to the ad's height so every ad screen is laid out with
  the ad's space from its first frame, and nothing moves when the ad loads.
- **Finish and skip actions.** A list of `OnboardingAction`s run in order, each
  awaited: `markCompleted`, `navigate`, `when` for a conditional step, or any
  async function, such as opening a paywall. A failing action stops the
  sequence unless `continueOnError`; each can have a `timeout`.
- **Layout.** `OnboardingControlsLayout.row` (skip, dots, next),
  `stacked` (dots over a centered next, leaving the bottom for an ad) or
  `fullWidthButton`, per flow or per page; `OnboardingFlowStyle` for colors,
  text styles, padding and transitions; `pageBuilder` and `controlsBuilder` to
  replace either, and `screenBuilder` (flow or page) to arrange a whole screen
  from its content, controls and ad.

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
