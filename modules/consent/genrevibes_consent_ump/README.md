# genrevibes_consent_ump

Google User Messaging Platform implementation of the `ConsentProvider` contract
declared by `genrevibes_consent`. UMP ships inside `google_mobile_ads`, so this
adapter carries that dependency and the neutral consent package does not.

Form presentation goes through the SDK's own
`loadAndShowConsentFormIfRequired`, which presents a form only while consent is
still required. Manual load-then-show implementations re-present the form after a
dismissal, trapping the user in a loop; delegating the check avoids that class of
bug entirely.

`ConsentStatus.notRequired` maps to a state that permits personalized work. The
SDK is wrapped by `UmpClient`, an injectable boundary, so the adapter is tested
without platform channels, and every SDK fault is normalized to a `KitError` with
a `ump_*` provider code.

Debug geography and test device identifiers are supplied through the neutral
`ConsentDebugConfig`, so application code never imports a consent vendor to
configure testing. An inactive configuration produces default request parameters,
so a production build cannot accidentally force a region.
