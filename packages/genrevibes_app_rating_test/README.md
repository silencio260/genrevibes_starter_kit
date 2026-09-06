# genrevibes_app_rating_test

Shared contract tests for GenRevibes store review adapters. Each adapter calls
`runStoreReviewProviderContractTests` from its own suite, so every review
provider behaves identically from an application's point of view.

The suite covers identifier stability, rejection of work before initialization,
idempotent initialization and disposal, availability reporting, review requests,
and the store-listing fallback.

This package is a library of tests rather than a test folder, so `test` is a
runtime dependency rather than a development one.
