# genrevibes_device_identity_platform

Platform sources for `genrevibes_device_identity`: an App Tracking
Transparency-backed `AdvertisingIdSource` and a `device_info_plus`-backed
`VendorIdSource`.

Only iOS has a tracking authorization flow, so off iOS the advertising source
reports `notSupported` without touching the plugin. Apple returns an all-zero
identifier when tracking is not authorized; that is reported as absent rather
than passed along as if it were an id.

Both plugins sit behind injectable clients, so the sources are tested without
a device. The neutral package never imports either plugin.
