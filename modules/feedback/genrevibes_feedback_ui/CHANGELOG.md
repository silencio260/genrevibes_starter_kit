# Changelog

## 0.1.0-dev.1

- Add `openFeedbackPage` and `FeedbackPage`: feedback and contact pages with
  email, message and optional screenshots, validated, sent through any
  `FeedbackProvider`, with sending, success and failure states.
- A full page with an app bar, styled by `FeedbackPageTheme` to match the
  app's own settings pages, rather than a bottom sheet.
- The scaffold makes room for the keyboard and the form scrolls, so no field
  overflows with the keyboard open.
- Screenshots come from an app-supplied `FeedbackScreenshotPicker`, keeping
  image pickers out of the kit.
