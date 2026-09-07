# genrevibes_analytics_mixpanel_replay

Optional Mixpanel session-replay lifecycle and root-widget integration. It is
separate from `genrevibes_analytics_mixpanel` because the replay SDK currently
requires a much newer Dart and Flutter baseline than Mixpanel event tracking.

Replay is privacy masked by default and its default sample percentage is zero.
An application must explicitly choose a non-zero percentage and coordinate
start, stop, identity, and consent with its analytics composition root.
