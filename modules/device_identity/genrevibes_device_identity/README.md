# genrevibes_device_identity

A stable per-install identifier, plus best-effort vendor and advertising
identifiers, with no platform plugin in the neutral package.

`installId` is the identifier every feature keys on: generated once with a
pure-Dart secure UUID, persisted through `genrevibes_storage`, and adopted from
the legacy `device_uuid` key so existing users keep their analytics history.

Tracking is never prompted at initialization. An out-of-context prompt at launch
is rejected by App Store review, so `resolve(promptTracking: true)` is called
from a screen that gives it context, typically after onboarding, and the
identity upgrades from a bare install id to one carrying an advertising id.

Platform sources fail quietly: identity must exist before anything that could
report a failure is running, so an unavailable vendor or advertising id yields
`null`. Unwritable storage is the one hard failure, because inventing an id
that will change on the next launch is worse than reporting the fault.
