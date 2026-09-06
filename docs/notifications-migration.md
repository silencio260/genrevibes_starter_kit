# Notification migration assessment

## Compared implementations

The active Story Saver and `deprecated_old_version_1` contain effectively the
same OneSignal wrapper. It initializes the static SDK, enables verbose logging,
prints permission/subscription identifiers and tokens, wires an in-app message
prompt, and requests permission from the storage-permission flow. The legacy
starter-kit package exposes only an abstract `PushNotificationsRepository`; it
does not contain a OneSignal implementation.

Story Saver's working `flutter_local_notifications` usage is separate and
limited to immediate “auto save complete” notifications. Workmanager performs
the recurring auto-save work; it is not a persistent reminder/campaign
scheduler.

## Problems preserved by copying the current code

- Permission prompting is coupled to unrelated storage permission onboarding.
- Repeated initialization can add duplicate OneSignal observers and click
  listeners.
- Permission, provider opt-in, subscription ID, and platform token are collapsed
  into logs, so “unsubscribed” has no reliable, queryable cause.
- Verbose production logging prints subscription IDs and push tokens.
- `Future.delayed` is created but not awaited before adding the in-app trigger.
- OneSignal-only naming (`player ID`) leaks through the starter-kit contract.
- Remote push cannot guarantee every-few-hours delivery for devices that are
  opted out, offline, or denied OS permission.

## New package mapping

- `genrevibes_notifications` owns provider-neutral state, events, safe
  diagnostics, local schedule models, and campaign-source composition.
- `genrevibes_notifications_onesignal` owns the OneSignal SDK, attaches each
  listener once, removes it on disposal, and never prompts during initialize.
- `genrevibes_notifications_local` owns persistent OS schedules for immediate,
  one-shot, fixed interval, and daily notifications. It never prompts during
  initialize and requires an explicit device IANA timezone.

A host can use remote config by decoding its validated values into a
`NotificationCampaignSource`, then layering it over a
`StaticNotificationCampaignSource`. Reserved campaign IDs let refresh cancel
removed remote campaigns without cancelling local notifications belonging to
other app features.

## Migration order for Story Saver

1. Compose `OneSignalPushProvider` at app startup without requesting permission.
2. Replace developer token/ID printing with `toSafeDiagnostics()` and record the
   issue names through the selected analytics sink.
3. Move the permission request to a dedicated onboarding/settings action.
4. Route notification opens from the neutral event stream into app navigation.
5. Replace AutoSaveService's direct notification plugin call with
   `LocalNotificationScheduler.show`.
6. Add reminder campaigns through the persistent local scheduler and a reserved
   ID set; keep Workmanager only for actual background auto-save work.
7. Remove direct OneSignal and local-notifications imports from the app after
   release behavior has been verified on Android and iOS.

This slice makes the architecture testable and migration-ready. Production
release approval still requires native Android/iOS builds, permission-state
device tests, timezone/DST tests, killed-app delivery tests, and OneSignal
dashboard-to-device integration tests.
