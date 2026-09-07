# genrevibes_auth_test

Shared contract tests for GenRevibes authentication adapters. Each adapter
calls `runAuthProviderContractTests` from its own suite, so every provider
behaves identically from an application's point of view.

The suite covers identifier stability, rejection of work before initialization,
idempotent initialization and disposal, guest sign-in, current-state replay on
`userChanges`, sign-out, and the rule that an unsupported request fails rather
than silently succeeding.

Capability-gated behavior is skipped rather than failed: an adapter that
declares `linking: false` is not asked to link. The linking test asserts the
property that matters, that the account id survives the upgrade, because a
provider that returns a new id has silently orphaned the guest's data.

This package is a library of tests rather than a test folder, so `test` is a
runtime dependency rather than a development one.
