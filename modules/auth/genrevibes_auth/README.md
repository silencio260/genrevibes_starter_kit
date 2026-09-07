# genrevibes_auth

Provider-neutral authentication contracts. Models a signed-in identity, the
requests that produce one, and the normalized reasons an attempt fails. It
imports no authentication SDK.

Federated requests carry **tokens**, they do not run the vendor sign-in flow.
Acquiring a Google or Apple token is a separate concern with its own plugin,
platform setup and release cadence, so an app using only email and password
never compiles a social sign-in SDK. It also keeps this contract clear of
`google_sign_in`, which now requires a Flutter floor above the family's.

`linkCredential` is a first-class operation, not a variant of sign-in. An
anonymous user is a real, persistent account; signing in with a second method
instead of linking creates a separate account and orphans everything the guest
created.

`AuthFailureReason` normalizes provider errors so application code never
matches vendor strings. `requiresRecentLogin` is the one worth handling
explicitly: account deletion returns it after a long session, and it means
re-authenticate and retry rather than fail.
