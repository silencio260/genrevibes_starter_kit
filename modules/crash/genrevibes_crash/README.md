# genrevibes_crash

Provider-neutral crash reporting. The package owns the report model, the
reporter contract, and a coordinator that applies the collection decision once
and fans reports out. It imports no crash SDK and no Flutter.

`CrashReportingConfig.collectionEnabled` has no default. Reporting local debug
crashes pollutes the dashboard and hides real regressions, so the application
states its intent, typically `!kDebugMode`.

`CrashReport.error` is `Object` rather than a framework type. An adapter may
recognise `FlutterErrorDetails` and route it to a richer SDK call, but the
contract stays usable from pure Dart.

`CrashCoordinator.report` is safe to call from inside an error handler. It never
throws, and a failing reporter degrades health instead of masking the original
error. A `CrashObserver` lets the application mirror reports into analytics or
logging without this package depending on either.

Framework hooks (`FlutterError.onError`, `PlatformDispatcher.onError`, guarded
zones) live in the adapter package because they need Flutter types. Install them
once, from `main`, and let nothing else record errors on its own path.
