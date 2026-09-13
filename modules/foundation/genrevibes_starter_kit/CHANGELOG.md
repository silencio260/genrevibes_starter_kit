## 0.1.0-dev.1

## Unreleased — 2026-09-13

- Add manual deferred startup, per-registration timeouts, early stop guards, continued cleanup and complete module-health lookup.

- Add `moduleTimeout`, bounding each module's `initialize()` so a vendor
  callback that never fires degrades that module instead of suspending startup.
- Log module initialization start, readiness and failure through `KitLogger`.
- Add lazy enabled/disabled module registration.
- Add required/optional startup failure policy and aggregate health.
- Add concurrent initialization coalescing and reverse-order disposal.
