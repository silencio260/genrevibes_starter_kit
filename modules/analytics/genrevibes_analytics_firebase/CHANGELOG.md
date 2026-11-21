# Changelog

## Unreleased

- **Breaking:** `sdkManagedAdPlatforms` defaults to `{'appodeal'}`
  (`defaultSdkManagedAdPlatforms`). `genrevibes_ads_appodeal` now ships
  Appodeal's Firebase adapter, and the app's own Firebase copy of Appodeal
  revenue is deprecated as redundant and less accurate. Other sinks still get
  it. Pass `const {}` to restore manual delivery.

- Add `LaunchJourney` (moved from Lunaris): measures the path from a cold
  start to the app's home screen. Every event routed through it gets
  `launch_number`; on launches 1 and 2 the pre-home events are also sent as
  `l1_<name>` / `l2_<name>` (revenue is never copied). Records startup steps
  with `ms_since_launch`, leaving and returning before home, and on the next
  launch `previous_launch_abandoned`. Holds events until analytics is ready
  and sends nothing on Google's test devices. Configured per app with
  `LaunchJourneyConfig`. Adds a dependency on `genrevibes_storage`.

- Keep Google's automated test phones out of analytics. The package is now an
  Android plugin that reads Firebase Test Lab's `firebase.test.lab` setting
  (Play's pre-launch report and review checks run on Test Lab). On those
  phones `FirebaseAnalyticsSink` turns Firebase collection off at
  `initialize` and sends no events, user IDs or user properties. Hosts call
  `GoogleTestDevice.check()` to keep their other providers off as well.
  `FirebaseAnalyticsClient` gains `disableCollectionOnTestDevice()`; custom
  clients must implement it.

- Add `FirebaseScreenTracking.navigatorObserver`, so navigation reaches
  Firebase as native `screen_view` events. Without it GA4's screen reports and
  DebugView had no navigation at all, and custom events carried no screen
  context.

## 0.1.0-dev.1

- Add Firebase Analytics lifecycle, event, consent, identity, and user-property
  integration.
- Normalize unsupported Firebase property values without leaking SDK types.

