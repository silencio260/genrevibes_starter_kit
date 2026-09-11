# genrevibes_consent_appodeal

Appodeal consent manager implementation of the `ConsentProvider` contract
declared by `genrevibes_consent`. The consent manager ships inside the Appodeal
SDK and is built on Google's User Messaging Platform with IAB TCF v2 support, so
an app that mediates through Appodeal needs neither `google_mobile_ads` nor
`genrevibes_consent_ump`.

`requestConsent` updates consent information, then presents the form once, and
only when the status is `required`. It never re-presents after a dismissal.
Presentation waits for the user; only the network steps are bounded by
`timeout`.

If consent information updates but no form loads, the user is reported as
`notRequired`: no form is offered to them. If consent information cannot be
updated at all, the request fails and `ConsentGate` fails open.

The Flutter plugin exposes no debug geography, so `ConsentDebugConfig` does not
apply. The SDK is wrapped by the injectable `AppodealConsentClient`.
