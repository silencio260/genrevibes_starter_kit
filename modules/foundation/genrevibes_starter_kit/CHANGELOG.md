## 0.1.0-dev.1

- Add `moduleTimeout`, bounding each module's `initialize()` so a vendor
  callback that never fires degrades that module instead of suspending startup.
- Log module initialization start, readiness and failure through `KitLogger`.
- Add lazy enabled/disabled module registration.
- Add required/optional startup failure policy and aggregate health.
- Add concurrent initialization coalescing and reverse-order disposal.
