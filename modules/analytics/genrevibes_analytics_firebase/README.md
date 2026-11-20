# genrevibes_analytics_firebase

Firebase Analytics implementation of `AnalyticsSink`.

The host application initializes Firebase before initializing this sink. Crash
reporting is intentionally excluded and will be provided by a separate
observability adapter.

## Google's test phones

Play's pre-launch report and review checks run the app on Firebase Test Lab
devices. They are robots, so they must not count as users. This package is an
Android plugin that reads Test Lab's `firebase.test.lab` system setting, and
the sink acts on it by itself with no host wiring:

- `initialize` turns Firebase collection off on a test phone (and keeps it off
  if consent later asks for it on); it stays on everywhere else, as before.
- `track`, `identify` and `setUserProperties` send nothing there.
- `sink.onGoogleTestDevice` reports what `initialize` found.

Firebase still logs `first_open` natively before any Dart runs, so one may
arrive per test device. Other providers are the host's to skip; read the same
answer (cached per process) before building them:

```dart
final robot = await GoogleTestDevice.check();
final mixpanel = token.isEmpty || robot ? null : MixpanelAnalyticsSink(...);
```

Android only: `check()` is false on iOS and web. Human reviewers on ordinary
phones and other emulators are not detected. Tests inject
`isGoogleTestDevice:` on the sink or set `GoogleTestDevice.debugOverride`.

## Launch journey

`LaunchJourney` measures each cold start up to the app's home screen, so a
first-launch funnel (splash → language → sign-in → home) can be read straight
from events and a user who leaves is the last step they reached.

What it adds:

- **`launch_number`** on every event it delivers: 1 for this install's first
  cold start, 2 for the second, and so on. Reinstalls start again at 1 (it is
  tied to Firebase's app instance id, which Android backup can't restore).
  Installs that onboarded before the journey existed count as 3+.
- **Prefixed copies.** On launches 1 and 2 every event sent before the home
  screen first shows is sent twice: `sign_up` and `l1_sign_up`. After home, and
  from launch 3, only normal names. `ad_impression` is never copied and copies
  drop `value`/`currency`, so revenue is not counted twice. Don't route
  `screen_view` through it (GA4 reserves the name); the steps cover screens.
- **Steps with timing.** `app_launch`, the configured screen steps,
  `no_internet_shown`, `home_reached` and any app step carry
  `ms_since_launch`.
- **Leaving.** `splash_abandoned` (backgrounded during the splash),
  `journey_left_app` / `journey_resumed` (`away_ms`) after it, and on the
  next launch `previous_launch_abandoned` (`step_reached`, `previous_ms`).
- **Held until ready, silent on robots.** Events before `attach` are kept in
  order. On Google's test devices (`GoogleTestDevice`) nothing is sent.

Wiring (four places):

```dart
// 1. main(), right after WidgetsFlutterBinding.ensureInitialized():
LaunchJourney.instance.start(const LaunchJourneyConfig(
  homeScreen: 'tab_home',
  screenSteps: {
    'splash': 'splash_shown',
    'language_select': 'language_select_shown',
    'welcome': 'welcome_shown',
  },
));

// 2. Once the analytics pipeline exists:
await LaunchJourney.instance.attach(
  send: (name, props) => pipeline.track(AnalyticsEvent(name: name, properties: props)),
  store: SharedPreferencesKeyValueStore(),
  alreadyOnboarded: onboarding.isCompleted,
);
// If startup fails before the pipeline exists:
// LaunchJourney.instance.attachDirectToFirebase(store: ...).

// 3. The app's single track method:
void track(String name, Map<String, Object?> props) =>
    LaunchJourney.instance.deliver(name, props, send);

// 4. The screen tracker, also before analytics is ready:
LaunchJourney.instance.screenShown(screenName);
```

Optional hooks: `step` / `stepOnce` for the app's own startup steps (for
example `startup_runtime_ready`, `account_check_finished`),
`launchAdShown()` and `splashFinished(...)` from the splash's ad, and
`splashCapReached` / `splashRemaining` when the app caps its splash at
`LaunchJourneyConfig.splashCap` (the journey only reports the cap; the app
enforces it).

Register `launch_number`, `ms_since_launch` and `step_reached` as GA4 custom
dimensions to use them outside Explorations and DebugView.

## Revenue forwarded by a native SDK

When a mediation SDK sends its own `ad_impression` events directly to Firebase,
configure its platform name on this sink to suppress the pipeline's manual
copies:

```dart
FirebaseAnalyticsSink(
  sdkManagedAdPlatforms: const {'appodeal'},
  logger: logger,
)
```

The filter matches `ad_impression` and the exact `ad_platform` property after
pipeline event-name resolution. It applies only to Firebase. Other sinks still
receive callback events, including their revenue precision; all other events
and providers are forwarded normally. Firebase collection, identity, and
lifecycle behavior are unchanged. The empty default preserves manual delivery
for hosts that have not enabled native SDK forwarding. Use canonical event
names when native forwarding owns Firebase revenue; renaming a manual event
would bypass this filter.

For Appodeal, the **host app** declares the vendor Firebase service adapter in
Android Gradle alongside its other native SDKs. For `stack_appodeal_flutter`
4.3.1's published dependency set this is
`com.appodeal.ads.sdk.adapters:firebase:23.2.0.0`; verify the installed vendor
version and resolved Firebase dependencies when upgrading. The host initializes
Firebase using its own `google-services.json` and initializes Appodeal once.
Each Appodeal app must enable **Firebase Tracking** and set **Firebase Ad Revenue
Event Name** to `ad_impression` in Attribution Settings. **Firebase Config Keys**
are optional Remote Config parameter names, not credentials, and can stay empty.
No per-impression Firebase logging call is required for that native route.

Enable this option only together with the native adapter and dashboard setup;
otherwise manual revenue will be skipped without a native replacement. A
successful pipeline dispatch of a filtered event means it was intentionally
handled locally, not that Firebase received an event; a debug log explains the
skip. Verify the native event independently in Firebase DebugView using live
inventory. Audit linked AdMob automatic reporting separately before treating
aggregated revenue as deduplicated across every SDK.

