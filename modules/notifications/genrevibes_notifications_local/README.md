# genrevibes_notifications_local

Optional persistent local scheduler backed by `flutter_local_notifications`
19.x. This adapter requires Dart 3.4 and Flutter 3.22, but those requirements
do not affect apps that only install the neutral or OneSignal packages.

It supports immediate, one-shot, arbitrary fixed-interval, and daily local
notifications. Initialization never requests notification permission; the host
chooses the correct onboarding moment and calls `requestPermission()`.

The host must provide the device's current IANA timezone (for example,
`Africa/Lagos`). Inexact-while-idle Android scheduling is the default so exact
alarm permission is not silently required. Native Android/iOS setup described
by `flutter_local_notifications` is still required in each host app.
