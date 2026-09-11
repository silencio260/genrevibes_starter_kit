# Changelog

## 0.1.0-dev.2

- `AppodealConsentProvider` implements `ConsentFormPreviewProvider`. An Android
  plugin calls Google's User Messaging Platform directly with the simulated
  region and testing forced, and refuses in builds that are not debuggable.
- `AppodealConsentProvider` implements `ConsentSignalsReader`, reading the
  stored IAB TCF v2 and GPP values on Android.

## 0.1.0-dev.1

- Add `AppodealConsentProvider` over the consent manager in
  `stack_appodeal_flutter` 4.x, with single-presentation requests, privacy
  options, and revoke.
- Add the injectable `AppodealConsentClient` boundary.
