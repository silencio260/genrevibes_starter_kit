# genrevibes_system_ui

The phone's system navigation bar — the back, home and recents buttons, or the
gesture handle — for GenRevibes apps. Hidden on every screen by default, shown
on the screens that ask for it, and shown everywhere for developers while their
switch is on.

Flutter's `SystemChrome` can hide the navigation bar on its own only without
Android's immersive behavior, so the first touch brings it back for good. This
package's Android plugin hides it the way Android intends: a swipe from the
bottom edge shows it for a moment, and it hides again by itself. The status bar
is left alone.

## Composition

```dart
// Bootstrap:
final navigationBar = NavigationBarController(store: store, logger: logger);
await navigationBar.initialize();
navigationBar.setDeveloperMode(developerAccess.current.isGranted);
developerAccess.changes.listen(
  (access) => navigationBar.setDeveloperMode(access.isGranted),
);

// App root:
NavigationBarScope(
  controller: navigationBar,
  child: MaterialApp(
    navigatorObservers: <NavigatorObserver>[navigationBar.observer],
    // ...
  ),
);

// A screen that shows the bar:
NavigationBarVisibility(visible: true, child: Scaffold(/* ... */));
```

## Behavior

- **Who decides.** For the screen on top: its `NavigationBarVisibility`, then
  its route name in `routes`, then `visibleByDefault` (false). A dialog, bottom
  sheet or menu keeps the bar of the screen under it unless it asks itself.
- **Developers.** While `setDeveloperMode(true)`, the developer switch
  (`setDeveloperShowsEverywhere`, on by default, remembered under
  `NavigationBarKeys.developerShowsEverywhere`) shows the bar on every screen.
  Turn it off to see screens the way users do. The Starter Kit Lab has the
  switch on its Navigation bar page.
- **Timing.** A change is applied after the frame, so a pushed screen's own
  request arrives first and the bar does not flicker.
- **Kept applied.** Android shows the bar again when another window, such as a
  full-screen ad, takes focus on older versions, and Flutter rewrites the
  system UI flags on resume. The plugin applies the requested state again each
  time the app's window regains focus.
- **Full-screen ads.** An ad SDK shows interstitials and rewarded ads in an
  activity of its own, whose window has both system bars. Once initialized, the
  controller has the plugin show every other activity in the process full
  screen from the moment it starts, before it is drawn: status bar hidden, and
  the navigation bar hidden unless developer access is granted and the
  developer switch is on (`overlayNavigationBarVisible`). A swipe from an edge
  shows a bar for a moment. Activities whose class name starts with one of
  `overlayExclusions` keep their bars — by default
  `defaultOverlayExclusions`: Flutter, billing, RevenueCat, sign-in, Google
  Play prompts and OneSignal. `fullScreenOverlays: false` leaves every
  activity alone.
- **Layout.** A hidden bar takes no space: `MediaQuery.padding.bottom` drops to
  the gesture area, so bottom content moves down. Pad with `MediaQuery`, not a
  fixed inset. With three-button navigation, a hidden bar hides Back, so give
  every screen its own way back.
- **Root navigator only.** Routes in nested navigators are not tracked.

Android only. On other platforms nothing is changed and `isSupported` is false.
