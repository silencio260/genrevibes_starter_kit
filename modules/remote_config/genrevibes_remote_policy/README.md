# genrevibes_remote_policy

The remote-config schema every portfolio app shares, and the glue that applies
it. Three concerns, all provider-neutral: ad timing, session replay, and
analytics event names.

`AdsPolicyKeys` are the production keys already live in every Firebase project,
with Story Saver's bundled defaults. They are deliberately not tidied:
`time_before_first_rewared_ad` is misspelled in production and stays misspelled
here, because renaming a key silently resets its value to the default in every
app on the next release. `ads_enabled` is the one addition, a kill switch that
disables every placement without a release.

`AdsPolicyConfig` is the typed view, and `AdsRemotePolicyBinder` keeps an
`AdPolicyController` tuned to it through `updatePlacements`, so a tuning change
lands live without recreating the controller and losing suppression state.

`SessionReplayPolicyKeys` are the four keys that govern replay:
`session_replay_enabled` as a kill switch, `session_replay_percent` as the
share of installs recorded, and `session_replay_mask_text` /
`session_replay_mask_images` for what those recordings show. Replay is the most
expensive thing an analytics provider bills for and the most sensitive thing it
stores, so both the volume and the privacy of it move without a release.

The defaults are what the portfolio ships today: 100% of installs, unmasked. A
masked replay is grey boxes moving around and cannot show where a user got
stuck, which is the only thing replay is paid for — so masking is a key rather
than a constant so it can be turned on for everyone, immediately, if a screen
ever renders something that should not be recorded. Turning the percentage
down is likewise the deliberate act, done while watching the bill.

`SessionReplayRemotePolicyBinder` keeps a `SessionReplayController` tuned to
those values. Recording starts and stops in place; masking reaches the plan
immediately but the SDK only on the next launch, because providers fix masking
when they are configured.

`AnalyticsNamesSchema` gives each of the portfolio's canonical event names a
remote key (`event_<field>`, the historical convention) defaulting to the
canonical literal. `RemoteAnalyticsEventNames` implements the pipeline's
`AnalyticsEventNames` resolver, so an override renames the event in every sink
and every kit emitter, and a blank override keeps the canonical name.

`PortfolioRemoteConfigSchema.build` combines all three with an app's own keys, and
`PortfolioRemoteConfigSettings` records the shared fetch timeout and interval.
