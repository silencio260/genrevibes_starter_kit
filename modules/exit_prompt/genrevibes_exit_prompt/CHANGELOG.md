# Changelog

## Unreleased — 2026-09-13

- Align the Dart minimum with the existing Flutter 3.27 requirement.

## 0.1.0-dev.1

- Add `ExitGuard`, which intercepts Back on the app's root screen and asks in
  the style `ExitPromptConfig` resolves, built fresh on each press so remote
  config, premium and ad availability are read at that moment.
- Add `ExitPrompt.show` and seven styles: `ad_sheet`, `ad_dialog`,
  `features_sheet`, `offer_sheet`, `confirm_dialog`, `double_tap` and `none`.
  A style missing what it needs — an ad, features, an offer — falls back.
- The Exit button is `standard` or `dimmed` (`ExitButtonEmphasis`).
- Ad-agnostic: an `ExitPromptAd` is a builder and the height kept for it.
- The default style is `featuresSheet`, falling back to `confirmDialog`
  without features. Google Play treats ads triggered by exiting the app as
  disruptive, so no default puts an ad in the prompt.
