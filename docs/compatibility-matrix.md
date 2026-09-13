# Compatibility requirements

These are declared package requirements, not a claim that every minimum was
built in this run. Install only the capabilities the app uses; optional SDKs
raise the requirement only for apps selecting them.

| Flutter floor | Packages |
| --- | --- |
| 3.19 | Most neutral contracts and lower-floor adapters; check each pubspec |
| 3.22 | Local notifications adapter |
| 3.27 / Dart 3.6 | RevenueCat, PostHog, Appodeal native UI, feedback UI, splash, exit prompt and Kit Lab |
| 3.38 | Optional Mixpanel replay adapter |

Kit Lab depends on the exit-prompt UI and uses newer Flutter UI APIs, so it now
declares Flutter 3.27 and Dart 3.6. UI packages already declaring Flutter 3.27
also declare its Dart 3.6 floor. PostHog keeps its existing SDK minimum 5.39.
No vendor versions were changed by this hardening work.

The package pubspecs are the source of truth. Existing compatibility scripts
are historical tooling; their old grouping is not evidence of a successful
minimum-version build. This run used source inspection and formatting, not
minimum-toolchain or native builds. CI: deferred TODO at the owner's request.
