# Changelog

## 0.1.0-dev.1

- Add `SplashFlow`, which runs an app's launch within `maxWait`: the app's own
  work, then the ad it resolves, loaded and shown after a minimum time, then
  `onFinished` with a `SplashOutcome` saying what became of the ad.
- Add `SplashLoadingView`, a logo and title above a progress bar with its
  percentage and "This action can contain ads" when an ad may follow, styled
  by `SplashLoadingStyle` and `SplashLabels`.
