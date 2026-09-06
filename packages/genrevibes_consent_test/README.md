# genrevibes_consent_test

Shared contract tests for GenRevibes consent provider adapters. Each adapter
calls `runConsentProviderContractTests` from its own test suite, so every
consent platform behaves identically from an application's point of view.

The suite covers identifier stability, rejection of work before initialization,
idempotent initialization and disposal, resolution to a settled state, and the
rule that `notRequired` permits personalized work.

This package is a library of tests rather than a test folder, so `test` is a
runtime dependency rather than a development one.
