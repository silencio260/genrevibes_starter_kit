# genrevibes_notifications_onesignal

Optional OneSignal implementation of `genrevibes_notifications`.

The provider registers permission, subscription, foreground-receipt, and click
listeners exactly once and removes them on disposal. `getSubscriptionState()`
reports permission, provider opt-in, subscription ID presence, and token
presence independently; safe module diagnostics never include the actual IDs
or token.

Permission prompting is never performed during initialization. The host app
chooses the appropriate onboarding moment and calls `requestPermission()`.
Verbose OneSignal logging is off by default.
