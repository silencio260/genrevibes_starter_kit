# genrevibes_developer_access

Who gets the developer tools and test ads in a **store build**, and how.

A development build always has access. A store build grants it to a phone in
one of two ways:

- **Listed developer device.** The phone's hash appears on any of three lists:
  hardcoded in the app, `developer_device_hashes` in the env file (comma
  separated), or `developer_device_hashes` in remote config (a JSON array,
  bound by `DeveloperAccessRemotePolicyBinder` in `genrevibes_remote_policy`,
  so a phone can be added or removed without a release).
- **Passcode.** A hidden gesture opens a prompt (`DeveloperUnlockGesture` in
  `genrevibes_devtools`). The passcode comes from the build's
  `developer_passcode`, or `DeveloperAccessDefaults.passcode` when blank. A
  correct passcode grants access **until the app closes**. Three wrong attempts
  lock entry until a development build runs on the phone or the app is
  reinstalled.

`DeveloperAccess.servesTestAds` follows access exactly. A phone that can reach
the developer tools is one someone is testing on, and a live ad tapped there is
invalid traffic on the account that owns it.

## Why hashes

Every list ships to people who are not the developer: hardcoded and env values
are compiled into the binary, and remote config is downloaded by every install.
A raw device identifier in any of them is published. `DeveloperDeviceHash`
salts and SHA-256 hashes the identifier; the device hashes its own and compares.
The identifiers are random UUIDs, so a hash can be neither reversed nor
produced by another device.

The salt is portfolio-wide. The identifier hashed is the platform vendor ID —
Android's developer-scoped app set ID, iOS's `identifierForVendor` — which is
the same for every app from one developer on a device, so one hash covers a
phone in every app.

## Why not the advertising ID

Google Play's Ads policy: "The Android advertising identifier (AAID) must only
be used for advertising and user analytics." Unlocking developer tools is
neither. Google documents the app set ID for "analytics or fraud prevention",
and a user cannot reset it.

## What is never kept

The passcode, any attempt, and the device identifier are never logged, stored,
or reported. Storage holds a wrong-attempt count and the install marker it was
counted on — the marker, so a lockout restored by Android Auto Backup into a
reinstalled app is ignored.
