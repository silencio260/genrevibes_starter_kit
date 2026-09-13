# Changelog

## 0.1.0-dev.2

- Add `DeveloperAdSwitches`: device-local switches that turn ad formats, such
  as interstitials, off on a developer's own phone. They apply only while
  developer access is granted and are remembered under
  `DeveloperAccessKeys.disabledAdFormats`. The app asks `allows(format)`
  wherever it loads or shows that format.

## 0.1.0-dev.1

- Add `DeveloperAccessController`: developer access for store builds from a
  development build, a hashed developer device list (hardcoded, env, remote),
  or a session-only passcode with a persisted, reinstall-aware lockout.
- Add `DeveloperDeviceHash`, `DeveloperAccessConfig`, and
  `DeveloperAccessDefaults`.
