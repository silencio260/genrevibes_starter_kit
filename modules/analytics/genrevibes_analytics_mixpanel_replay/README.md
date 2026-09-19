# genrevibes_analytics_mixpanel_replay

Optional Mixpanel session-replay lifecycle and root-widget integration. It is
separate from `genrevibes_analytics_mixpanel` because the replay SDK currently
requires a much newer Dart and Flutter baseline than Mixpanel event tracking.

Replay is privacy masked by default and its default sample percentage is zero.
An application must explicitly choose a non-zero percentage and coordinate
start, stop, identity, and consent with its analytics composition root.

To let the shared rollout (`session_replay_enabled`, `session_replay_percent`,
developer overrides) decide recording, build the configuration with
`withSessionReplay(plan)` and attach `MixpanelSessionReplayRecorder` to
`SessionReplayController`. The recorder starts at 100% for installs the
controller selected and restarts recording after the app returns from the
background, which Mixpanel does not do on its own at a 0% configuration.
