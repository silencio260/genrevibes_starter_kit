# genrevibes_consent

Provider-neutral privacy consent for GenRevibes applications. It owns the consent
state machine, the debug configuration shape, and the gate that sequences consent
ahead of everything that depends on it. It imports no consent SDK.

Consent platforms are normally bundled inside an ad network's SDK, so each ad
network ships its own adapter package. An application depends on this contract
and selects one adapter during composition, which keeps consent gating available
to analytics-only apps that install no ad network at all.

`ConsentState.notRequired` permits personalized work. Treating it as a denial is
a common and expensive mistake, because it silently disables monetization and
measurement for every user outside a regulated region.

`ConsentGate` resolves consent once and exposes a `ready` future that ads and
analytics initialization can await. It replaces the ad-hoc global completer and
"already initialized" flag that applications usually grow for this ordering rule.
By default it fails open: a consent platform fault releases waiters in a
non-personalized state rather than hanging the app forever.
