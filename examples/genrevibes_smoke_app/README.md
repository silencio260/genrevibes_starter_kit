# GenreVibes native smoke app

This application is a compile-time and native plugin-registration gate for the
complete provider package family. It contains no SDK keys and deliberately does
not initialize vendors at runtime.

Run:

```sh
flutter test
flutter build apk --release
flutter build ios --release --no-codesign
```

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
