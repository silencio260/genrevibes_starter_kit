# genrevibes_remote_policy

The remote-config schema every portfolio app shares, and the glue that applies
it. Two concerns, both provider-neutral: ad timing and analytics event names.

`AdsPolicyKeys` are the production keys already live in every Firebase project,
with Story Saver's bundled defaults. They are deliberately not tidied:
`time_before_first_rewared_ad` is misspelled in production and stays misspelled
here, because renaming a key silently resets its value to the default in every
app on the next release. `ads_enabled` is the one addition, a kill switch that
disables every placement without a release.

`AdsPolicyConfig` is the typed view, and `AdsRemotePolicyBinder` keeps an
`AdPolicyController` tuned to it through `updatePlacements`, so a tuning change
lands live without recreating the controller and losing suppression state.

`AnalyticsNamesSchema` gives each of the portfolio's canonical event names a
remote key (`event_<field>`, the historical convention) defaulting to the
canonical literal. `RemoteAnalyticsEventNames` implements the pipeline's
`AnalyticsEventNames` resolver, so an override renames the event in every sink
and every kit emitter, and a blank override keeps the canonical name.

`PortfolioRemoteConfigSchema.build` combines both with an app's own keys, and
`PortfolioRemoteConfigSettings` records the shared fetch timeout and interval.
