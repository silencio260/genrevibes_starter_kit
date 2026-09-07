# Changelog

## 0.1.0-dev.1

- Print uncaught zone and platform errors in debug builds, where crash
  collection is normally disabled and nothing else presents them.
- Add `CrashlyticsReporter`, the injectable `CrashlyticsClient`, and
  `CrashHooks` for framework and zone error routing.
