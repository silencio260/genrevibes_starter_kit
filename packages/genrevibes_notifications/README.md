# genrevibes_notifications

Provider-neutral remote push state and local notification scheduling contracts.
OneSignal and `flutter_local_notifications` are optional adapters in separate
packages, so an app that does not select them will not resolve their native
plugins.

The push state reports OS permission, provider opt-in, subscription-ID presence,
and push-token presence independently. This makes “unsubscribed” diagnosable
without logging private identifiers or tokens.

`NotificationCampaignSource` accepts hardcoded campaigns, an app-owned remote
config decoder, or a fallback composition of both. The neutral package does not
depend on a remote-config vendor.
