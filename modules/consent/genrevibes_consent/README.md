# genrevibes_consent

Provider-neutral privacy consent for GenRevibes applications. It owns the consent
state machine, the debug configuration shape, and the gate that sequences consent
ahead of everything that depends on it. It imports no consent SDK.

Consent platforms are normally bundled inside an ad network's SDK, so each ad
network ships its own adapter package. An application depends on this contract
and selects one adapter during composition, which keeps consent gating available
to analytics-only apps that install no ad network at all.

`ConsentState.notRequired` reports the SDK's regional requirement result. It is
not an application-created consent grant. Advertising SDKs retain responsibility
for interpreting the stored signals and selecting available inventory.

`ConsentGate.ready` releases after a bounded consent attempt. With the default
`failOpen: true`, failure leaves the real snapshot intact and degrades health,
but completes initialization so the next module can start. Inspect health for
failure; do not equate successful sequence completion with consent obtained.
Set `timeout` to the app's chosen budget (eight seconds in Story Saver).
`failOpen: false` returns a failed result for hosts that require that policy.
Analytics consent is a separate app decision, not automatically tied to this gate.

## September hardening

Bound consent waits; release fail-open startup without fabricating consent or regional status. Stop safely during initialization.

See [portfolio adoption](../../../docs/portfolio-adoption.md) and
[implementation/check status](../../../docs/production-hardening-plan.md).
