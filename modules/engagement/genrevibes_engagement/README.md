# genrevibes_engagement

Retention tracking, user segmentation and prompt targeting, provider-neutral.
This is the code that exists as a byte-identical copy in nearly every portfolio
app; here it lives once, with tests, and every app reads the same rules.

`RetentionTracker` records opens and sessions in a `KeyValueStore` and derives
an `EngagementSnapshot` against an injected clock. Wrap the store in a
`MigratingKeyValueStore` seeded with `EngagementKeys.legacyKeys` and an existing
install keeps its history, lists included; the persisted formats match what the
hand-rolled trackers already wrote.

`UserTargetingPolicy` is pure: segment precedence (power > loyal > churned > at
risk > returning > first time > new), engagement level bands, the weighted
0–100 score, and every `shouldShow*` decision are functions of the snapshot
alone. Thresholds are injectable and default to production values.

Two deliberate differences from the copied trackers: a retention milestone is
reported once per install rather than on every open of that day, and day 30
actually fires, which the week-capped `hasReturnedOnDay` never allowed.

Analytics is reached through `EngagementObserver`. `AnalyticsEngagementObserver`
emits the portfolio's canonical event names fire-and-forget, so a slow sink can
never stall startup, and renames flow through the pipeline's
`AnalyticsEventNames`, never through this package.
