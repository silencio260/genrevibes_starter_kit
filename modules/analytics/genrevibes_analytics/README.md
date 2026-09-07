# genrevibes_analytics

Provider-neutral analytics contracts and a consent-aware multi-sink pipeline.

Firebase Analytics, PostHog, Mixpanel, and future SDKs belong in separate
adapter packages. A failed sink is reported without preventing healthy sinks
from receiving the same event.

The API is experimental until the first stable release.

