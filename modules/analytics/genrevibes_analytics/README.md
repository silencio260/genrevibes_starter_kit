# genrevibes_analytics

Provider-neutral analytics contracts and a consent-aware multi-sink pipeline.

Firebase Analytics, PostHog, Mixpanel, and future SDKs belong in separate
adapter packages. A failed sink is reported without preventing healthy sinks
from receiving the same event.

The API is experimental until the first stable release.


## September hardening

Track configured replay masking and applied recording; stop for stricter masking and remote disable. Continue cleanup after sink errors.

See [portfolio adoption](../../../docs/portfolio-adoption.md) and
[implementation/check status](../../../docs/production-hardening-plan.md).
