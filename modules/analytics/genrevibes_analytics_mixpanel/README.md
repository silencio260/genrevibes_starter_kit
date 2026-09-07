# genrevibes_analytics_mixpanel

Mixpanel events implementation of `AnalyticsSink`. Session replay deliberately
lives in the separate `genrevibes_analytics_mixpanel_replay` package so apps
that do not use replay do not compile its plugin.
