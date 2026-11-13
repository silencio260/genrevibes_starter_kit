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

## Google sign-in on Android

This adapter accepts a Google ID token; the app gets it with `google_sign_in`.
Three app-side settings decide whether that works in a release build:

- Register the SHA-1 of every signing key (debug, upload and Play App Signing)
  in Firebase, then download `google-services.json` again.
- Keep `@string/default_web_client_id` from resource shrinking in
  `android/app/src/main/res/raw/keep.xml`:
  `tools:keep="@string/default_web_client_id"` (add it to the list if the file
  exists). `google_sign_in_android` looks it up by name, so Flutter's release
  shrinking removes it and sign-in fails with `clientConfigurationError` in
  release builds only, while debug builds work.
- Test Google sign-in on an installed release build before shipping.

The module ships no Android resources, so it cannot add this keep rule for the
app: a library's `raw/keep.xml` would be replaced by the app's own file of the
same name.
