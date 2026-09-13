# genrevibes_analytics_posthog

PostHog implementation of `AnalyticsSink`, including optional session replay.
Configuration is application-owned and API keys are supplied at runtime or
with build-time environment values.


## September hardening

Export PostHogMaskWidget for sensitive host routes without a vendor dependency in neutral UI.

See [portfolio adoption](../../../docs/portfolio-adoption.md) and
[implementation/check status](../../../docs/production-hardening-plan.md).
