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
