# Changelog

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
