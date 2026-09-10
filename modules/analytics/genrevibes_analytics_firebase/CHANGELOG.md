# Changelog

## Unreleased

- Add `FirebaseScreenTracking.navigatorObserver`, so navigation reaches
  Firebase as native `screen_view` events. Without it GA4's screen reports and
  DebugView had no navigation at all, and custom events carried no screen
  context.

## 0.1.0-dev.1

- Add Firebase Analytics lifecycle, event, consent, identity, and user-property
  integration.
- Normalize unsupported Firebase property values without leaking SDK types.

