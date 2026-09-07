# genrevibes_crash_test

Shared contract tests for GenRevibes crash reporter adapters. Each adapter calls
`runCrashReporterContractTests` from its own suite, so Crashlytics, Sentry, or
any future reporter behaves identically from the application's point of view.

The suite covers identifier stability, rejection before initialization,
idempotent initialization and disposal, recording, and the rule that recording
succeeds while collection is disabled rather than failing the caller.

This package is a library of tests, so `test` is a runtime dependency.
