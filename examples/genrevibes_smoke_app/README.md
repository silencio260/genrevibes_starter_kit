# GenRevibes native smoke app

This application is a compile-time, launch-time, and native
plugin-registration gate for the complete provider package family. It contains
no committed SDK keys.

Run:

```sh
flutter test
flutter build apk --release
flutter build ios --release --no-codesign
```

## AdMob application ID

The Android manifest and iOS `Info.plist` carry Google's **public sample**
application ID. This is required, not optional. Google Mobile Ads registers
`MobileAdsInitProvider`, a `ContentProvider` that runs during `Application`
creation, before Flutter starts Dart. When the application ID is absent the SDK
throws `Invalid application ID` and the process dies at launch, whether or not
any Dart code ever touches the ads SDK. A real app must supply its own ID.

## Supplying credentials

Provider credentials are injected at build time and never committed. This app
keeps its own environment file at `env/dev.json`, which holds only the seven
keys the app actually reads. `env/` is git-ignored, so nothing there can reach
a commit.

To recreate it, copy the template and fill in what you need:

```sh
cp env.example.json env/dev.json
```

Because the file already contains only consumed keys, the plain Flutter command
works directly:

```sh
flutter run --dart-define-from-file=env/dev.json
```

The helper script is still preferred, and required when pointing at an
environment file that carries keys this app should not receive. It resolves the
file, strips every key the smoke app does not consume, and passes the remainder
to Flutter through a private temporary file that is deleted on exit:

```sh
bash ../../tool/run_smoke_app.sh
bash ../../tool/run_smoke_app.sh build apk --release
```

To check which keys would be injected without launching anything:

```sh
GENREVIBES_DRY_RUN=1 bash ../../tool/run_smoke_app.sh
```

Resolution order for the source file:

1. `$GENREVIBES_ENV_FILE`
2. `examples/genrevibes_smoke_app/env/dev.json`, then `env/local.json`
3. `../../env/dev.json`, the Story Saver file, when this repository is nested
   as a submodule

Pointing at the Story Saver environment is supported and requires no copying.
The script reads it in place and injects only `development_mode`,
`revenue_cat_api_key_*`, `one_signal_app_id`, `posthog_api_key`, `posthog_host`,
and `mixpanel_token`. Ad unit IDs, Firebase keys, and third-party server keys
present in that file are withheld and never reach the compiler.

Any provider whose key is absent reports itself as unconfigured on the app's
first screen. Nothing falls back to a committed credential, and no value is ever
displayed.

## Ad units are always test units

Ad unit IDs are deliberately **not** read from the environment file. Serving a
production ad unit from a non-store build is invalid traffic under the AdMob
program policies and can suspend the account that owns the unit. The smoke app
therefore always uses Google's public test units. `test/smoke_env_test.dart`
enforces this.

A successful build proves that the selected adapter dependency graph can be
assembled by one Android/iOS host. It does not replace provider dashboard,
purchase, ad-delivery, push-delivery, or permission testing on real devices.

Swift Package Manager is disabled for this smoke app because Mixpanel Session
Replay still requires the CocoaPods fallback. Remove that override after the
vendor supports Flutter's Swift Package Manager integration.

Android core-library desugaring is enabled because
`flutter_local_notifications` 19.x requires it. Host apps selecting the local
notification adapter must carry the same native build setting.

The iOS deployment target is explicitly set to iOS 13.0. The CI job upgrades
the smoke app within declared constraints before building, so it tests the
newest allowed provider graph rather than silently reusing an old lockfile.

## TODO: known gaps

Deferred, not forgotten. Recorded here so the next person does not assume this
app verifies more than it does.

### Add a launch gate to CI

**Not started. This is the important one.**

CI currently runs `flutter test` and `flutter build apk --release`. Neither
starts the Android runtime, so nothing here ever opens the app. Building and
launching are different failures, and only the first is currently gated.

This was not theoretical. The app built cleanly at 53.7 MB while crashing on
every launch, because Google Mobile Ads registers `MobileAdsInitProvider`, a
`ContentProvider` that runs during `Application` creation and killed the process
before Flutter reached Dart. A missing manifest entry, invisible to every
existing check.

The fix is one CI job that boots an emulator, installs the app, opens it, and
asserts a first frame, using `integration_test` plus
`reactivecircus/android-emulator-runner`. Any adapter that self-initializes
natively fails the same silent way, and several installed here do, so this gate
covers a whole class of defect rather than a single bug.

### Firebase adapters are link-only

`FirebaseAnalyticsSink` and `GenRevibesFirebaseRemoteConfigProvider` compile and
register, but cannot initialize. There is no `google-services.json`, no
`GoogleService-Info.plist`, and the `com.google.gms.google-services` Gradle
plugin is not applied. Firebase logs a warning instead of crashing, so this
stays invisible at runtime. Two of the thirteen adapters listed on the app's
first screen are therefore proven to link and nothing more.

### No provider is actually initialized

Environment values are read and turned into real configuration objects, but
those objects only drive a status display. The app proves the native graph
loads and the process survives. It does not exercise purchases, ad delivery,
push delivery, or permission flows. Wiring initialization behind a flag is what
would turn this into the integration harness the roadmap still lists as
missing.

### Stale test name

`test/widget_test.dart` names its case "lists every native adapter without
initializing SDKs". The second half no longer describes the design.
