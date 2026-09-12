# genrevibes_splash

The launch screen for GenRevibes apps: a loading bar while the app gets ready,
then, when the app allows one, a full-screen ad, then the app's own routing.
Every wait is bounded by `maxWait`, so a slow startup, a consent form or an ad
that does not fill never keeps a user on the splash.

## Composition

```dart
Scaffold(
  body: SplashFlow(
    maxWait: const Duration(seconds: 8),
    minDuration: const Duration(seconds: 2),
    // Work to wait for, such as reading where to go next.
    prepare: () => splashBloc.stream.firstWhere((s) => s.isDecided),
    // The ad for this launch, or null for none. Runs after `prepare`.
    resolveAd: () async {
      await kit.deferredStartupComplete; // consent before any ad request
      if (isPremium) return null;
      return SplashAdRequest(provider: ads, placement: AppPlacements.splash);
    },
    adExpected: splashAdsOn,
    onFinished: (outcome) {
      analytics.track('splash_ad_result', {'status': outcome.adStatus.name});
      Navigator.pushReplacementNamed(context, Routes.home);
    },
    builder: (context, progress) => SplashLoadingView(
      progress: progress,
      logo: Image.asset('assets/images/app-logo.png', width: 120),
      title: 'Story Saver',
      style: const SplashLoadingStyle(progressColor: Color(0xFF128C7E)),
    ),
  ),
);
```

## Behavior

- **Order.** `prepare`, then `resolveAd`, then the ad's load, each within what
  is left of `maxWait`. The screen stays at least `minDuration`, reaches 100%,
  pauses for `completionPause`, and only then shows the ad.
- **Progress.** The bar eases towards 95% over `maxWait` and reaches 100% only
  when the work is done, so it never sits full while the app still waits.
- **The disclosure** ("This action can contain ads") shows from the first frame
  when `adExpected` is true, and follows `resolveAd`'s answer after that.
- **The ad** shows only if it loaded in time and the app is in the foreground.
  With `SplashAdRequest.policy` it goes through `AdCoordinator`, so suppression
  and the display lock apply; without it, through the provider directly.
- **Outcome.** `SplashOutcome.adStatus` is `notRequested`, `shown`, `timedOut`,
  `notReady`, `blocked`, `failed` or `appInBackground`. A load that timed out
  keeps going in the provider, and its ad serves the next request for that
  format.
- **Custom look.** `builder` receives a `SplashProgress` (value, percent,
  phase, adExpected). Use `SplashLoadingView` or draw your own.

## Ad policy

Know which format the splash shows. AdMob's disallowed interstitial
implementations include "Do not place interstitial ads on app load and when
exiting apps", and that applies whenever AdMob serves the ad through mediation.
App open ads are the format made for launch screens. Rewarded ads must be
opted into by the user.
