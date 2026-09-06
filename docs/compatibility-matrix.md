# Compatibility matrix

The package family is tested in independent tiers so a high-floor optional SDK
does not raise the minimum for unrelated applications.

| Tier | Exact minimum Flutter | Packages |
| --- | ---: | --- |
| Base | 3.19.0 | Pure contracts, coordinator, AdMob, Firebase, Mixpanel events, PostHog, OneSignal, and SharedPreferences adapters |
| Local notifications | 3.22.0 | `genrevibes_notifications_local` |
| RevenueCat | 3.27.0 | RevenueCat core and optional hosted UI |
| Mixpanel replay | 3.38.0 | Optional Mixpanel session replay |
| Current | Stable channel | Every package and the Android/iOS native smoke app |

`tool/test_compatibility_tier.sh` is the source of truth for tier membership.
The GitHub Actions workflow runs every exact minimum and the moving stable
channel. Provider packages use their committed `pubspec_overrides.yaml` during
minimum tests so the lower supported vendor version is actually exercised.

The native smoke app resolves the newest provider versions allowed by package
constraints by running `flutter pub upgrade` in CI before each native build.
This gives the matrix both ends of the supported dependency range: minimum
provider versions at each Flutter floor and newest compatible provider versions
on current stable. Its committed lockfile records the last locally verified
provider graph; CI does not rely on that lockfile remaining current.

Passing the matrix is required before changing a package's documented Flutter
floor. Adding an optional adapter with a higher floor creates a new tier; it
must not raise the floor of provider-neutral or unrelated packages.

Changing a Dart/Flutter lower bound or moving a package between tiers requires
updating this document and the compatibility script in the same change.
