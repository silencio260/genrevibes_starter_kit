# Changelog

## 0.1.0-dev.2

- Require `posthog_flutter >=5.39.0`, for manual session-recording control that
  actually records on Android (broken before 5.38).
- Add `PostHogSessionReplayRecorder`, so replay can be started and stopped
  while the app runs rather than only at SDK setup.
- Add `GenRevibesPostHogConfiguration.copyWith` and `withSessionReplay`, which
  applies a resolved `SessionReplayPlan` before setup — the only moment masking
  can be set.
- State `surveys` explicitly, now that the SDK turns it on by default. Whether
  an analytics SDK may show an app's users a dialog is the app's decision.
- Default `maskAllTexts` and `maskAllImages` to false. A masked replay cannot
  show where a user got stuck; masking is now a remote key an application turns
  on for a reason.

## 0.1.0-dev.1

- Add PostHog events, consent, identity, profile properties, flush, and reset.
- Add explicit privacy-first session replay configuration.

