# Changelog

## 0.1.0-dev.1

- Add `DeveloperAccessController`: developer access for store builds from a
  development build, a hashed developer device list (hardcoded, env, remote),
  or a session-only passcode with a persisted, reinstall-aware lockout.
- Add `DeveloperDeviceHash`, `DeveloperAccessConfig`, and
  `DeveloperAccessDefaults`.
