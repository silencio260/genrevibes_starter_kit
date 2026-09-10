# Changelog

## 0.1.0-dev.3

- Add `SessionReplayController`, which resolves whether an install records
  session replay from a persisted rollout bucket, a policy, and a device-local
  developer override, and enforces it through a `SessionReplayRecorder`.
- Add the `SessionReplayRecorder` contract, plus `SessionReplayPolicy`,
  `SessionReplayPlan`, `SessionReplayOverride` and `SessionReplayKeys`.
- Depend on `genrevibes_storage` for the bucket and override.

## 0.1.0-dev.2

- Add the `AnalyticsEventNames` resolver contract, applied once in the pipeline
  so a renamed event reaches every sink and every kit emitter consistently.

## 0.1.0-dev.1

- Add analytics events, users, consent, sink, and delivery report models.
- Add a consent-aware pipeline with concurrent fan-out and failure isolation.

