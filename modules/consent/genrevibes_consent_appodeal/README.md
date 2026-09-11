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

Appodeal's consent manager never passes debug settings to Google's User
Messaging Platform, so `requestConsent` always uses the device's real location.

For development, the provider implements `ConsentFormPreviewProvider`.
`previewConsentForm` calls the platform directly, through this package's
Android plugin, with the `ConsentDebugConfig` region and testing forced, so no
device identifier is read. It refuses in a build that is not debuggable,
stores the answer like a real one (`reset` clears it), and is Android only. If
no form loads while the EEA is simulated, no consent message is published in
AdMob for the app.

The provider also implements `ConsentSignalsReader`. `readConsentSignals`
returns the IAB TCF v2 and GPP values (`IABTCF_TCString`, `IABTCF_gdprApplies`,
`IABGPP_HDR_GppString`, and the rest) from the app's default shared
preferences, where the platform writes them and Appodeal and its networks read
them. Android only. Outside a regulated region, the next consent update
overwrites a TC string written by a preview.

The SDK is wrapped by the injectable `AppodealConsentClient`.
