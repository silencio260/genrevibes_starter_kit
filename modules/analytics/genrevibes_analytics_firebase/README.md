# genrevibes_analytics_firebase

Firebase Analytics implementation of `AnalyticsSink`.

The host application initializes Firebase before initializing this sink. Crash
reporting is intentionally excluded and will be provided by a separate
observability adapter.

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

