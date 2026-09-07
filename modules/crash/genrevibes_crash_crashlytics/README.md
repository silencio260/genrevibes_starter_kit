# genrevibes_crash_crashlytics

Firebase Crashlytics implementation of the `CrashReporter` contract declared by
`genrevibes_crash`, plus the framework hooks that need Flutter types.

`CrashHooks.install` chains `FlutterError.onError` and
`PlatformDispatcher.onError` into a `CrashCoordinator`, keeping any previous
handler so a debugger or test binding still sees the error. `CrashHooks.runGuarded`
wraps `main` so an unawaited `Future` that fails still reaches the reporter.
Install once, from `main`, and let no other path record errors: a second wiring
double-reports every crash.

A `FlutterErrorDetails` payload is routed to `recordFlutterError` so library,
context and widget stack survive; anything else goes to `recordError` with the
report's source and information attached.

The SDK sits behind `CrashlyticsClient`, an injectable boundary, so this adapter
is tested without Firebase. Faults are normalized to `KitError` with a
`crashlytics_*` provider code, and a reporter fault degrades health rather than
throwing from inside an error handler.

Requires `Firebase.initializeApp` to have run; the application owns that call.
