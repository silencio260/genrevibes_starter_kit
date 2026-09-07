# genrevibes_auth_firebase

Firebase Authentication implementation of the `AuthProvider` contract declared
by `genrevibes_auth`. Firebase must already be initialized by the host before
this module starts.

It depends on `firebase_auth` alone. Google and Apple tokens arrive in the
neutral request, so an app using only email and password compiles no social
sign-in SDK, and the adapter stays clear of `google_sign_in`, which now
requires a Flutter floor above this family's.

Two behaviors are worth knowing. Registration is attempted only when sign-in
reports `user-not-found`, so a wrong password never silently creates a second
account. And linking preserves the account id, which is what lets a guest
become a permanent user without orphaning their data.

Firebase error codes are normalized to `AuthFailureReason` and carried in the
`KitError` metadata, so application code branches on a stable enum rather than
vendor strings. `network` and `cancelled` map to their own `KitErrorCode`s
rather than being lumped into provider failures.
