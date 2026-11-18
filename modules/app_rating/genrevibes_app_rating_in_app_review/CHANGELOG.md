# Changelog

## Unreleased

- Implement `requestReviewThenOpenListing()`, reporting how long the sheet
  request took and whether the listing opened.

## 0.1.0-dev.1

- Add `InAppReviewStoreProvider` with a platform-aware store listing fallback.
- Add the injectable `ReviewClient` boundary over the review and launcher plugins.
