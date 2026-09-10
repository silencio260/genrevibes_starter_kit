# genrevibes_device_identity_platform

Platform sources for `genrevibes_device_identity`: an App Tracking
Transparency-backed `AdvertisingIdSource`, and a `VendorIdSource` that reads
Android's app set ID and iOS's `identifierForVendor`.

The vendor ID is what developer devices are listed under (hashed, by
`genrevibes_developer_access`). On Android it is Google's app set ID, read by
this package's own small Android plugin: developer-scoped for Play installs, so
the same for every app from one Play developer account on a device, not
resettable by the user, and documented by Google for analytics and fraud
prevention. It used to be `Build.ID`, which names a firmware build and is the
same on every phone running it. A sideloaded install reports an app-scoped ID
instead, so its hash differs from the Play install's.

`InstallMarker` reads Android's first-install time over the same plugin, which
changes on reinstall and is not restored by Auto Backup.

Only iOS has a tracking authorization flow, so off iOS the advertising source
reports `notSupported` without touching the plugin. Apple returns an all-zero
identifier when tracking is not authorized; that is reported as absent rather
than passed along as if it were an id.

Both plugins sit behind injectable clients, so the sources are tested without
a device. The neutral package never imports either plugin.
