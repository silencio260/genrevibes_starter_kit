# Changelog

## 0.1.0-dev.1

- Add `NavigationBarController`, which decides whether the phone's system
  navigation bar shows, screen by screen: a screen's own request, then route
  names, then the default (hidden). Dialogs and sheets keep the bar of the
  screen under them. With developer access bound through `setDeveloperMode`,
  a remembered developer switch shows the bar on every screen.
- Add `NavigationBarVisibility`, a screen's request, and `NavigationBarScope`.
- Add the Android plugin, which hides the navigation bar with Android's
  immersive behavior — a swipe from the bottom edge shows it for a moment — and
  applies it again when the window regains focus.
- Show activities opened over the app, such as full-screen ads, full screen
  from the moment they start: no status bar, and the navigation bar only while
  the developer switch shows it on every screen. `overlayExclusions` keeps
  purchase, sign-in and other non-ad activities as they are;
  `fullScreenOverlays: false` turns it off.
