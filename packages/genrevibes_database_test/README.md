# genrevibes_database_test

Shared contract tests for GenRevibes document store adapters. Each adapter
calls `runDocumentStoreContractTests` from its own suite, so every store
behaves identically from an application's point of view.

The suite pins the behaviors that differ between naive implementations: a
missing document reads as absent rather than failing, `set` without `merge`
replaces while `set` with `merge` preserves, `update` fails on an absent
document, deleting an absent document succeeds, and `watch` emits the current
value on subscription.

It also asserts the boundary checks: a collection path where a document is
required, a document path where a collection is required, and a malformed
query all return `invalidConfiguration` rather than reaching the vendor.

This package is a library of tests rather than a test folder, so `test` is a
runtime dependency rather than a development one.
