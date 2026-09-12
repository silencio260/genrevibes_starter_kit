# Changelog

## 0.1.0-dev.3

- **Changed default:** `OnboardingPresentation.screens`. Every page is a
  complete screen — content, its own controls and, when it has one, its own ad
  — that swipes in as a unit, so ad screens and full-screen pages are distinct
  screens rather than one screen with its ad area taken away. The previous
  arrangement is `OnboardingPresentation.sharedControls`.
- `OnboardingScreenLayout.edgeToEdge`: artwork across the top edge to edge,
  taking the height the text, controls and ad leave, so an ad screen and a
  full-screen page are each laid out whole. `artworkFadeHeight` fades the
  artwork into the background above the title.
- `OnboardingScreenLayout.immersive`: artwork edge to edge with the text and
  controls over a fade.
- `screenBuilder`, on the flow and per page, arranges a whole screen from its
  `OnboardingScreenParts`; `OnboardingPage.controlsLayout` overrides the flow's.
- `OnboardingFlowStyle.adFreeControlsPadding` and immersive colors.
- `OnboardingAdSlot.reservedHeight` is now the ad area's fixed height on every
  ad page, from the first frame: the screen is laid out with the ad's space and
  nothing moves when it loads. It was a minimum height.
- `OnboardingAdSlot.sizeAnimation`: without a reserved height, an ad arriving
  after its screen grows into place; the shared ad area opens and closes
  smoothly.

## 0.1.0-dev.2

- Add `OnboardingFlow`: any number of pages, an optional ad-agnostic
  `OnboardingAdSlot`, finish and skip `OnboardingAction` sequences, three
  control layouts, `OnboardingFlowStyle`, and page and controls builders.
- Add `OnboardingAction` with `markCompleted`, `navigate` and `when`.
- Add the public `OnboardingPageIndicator`.
- `OnboardingPage.showAd`, for pages that should not show the flow's ad.

## 0.1.0-dev.1

- Add `OnboardingController` with completion state and legacy-key adoption.
- Add the theme-driven, embeddable `OnboardingView` presentation template.
