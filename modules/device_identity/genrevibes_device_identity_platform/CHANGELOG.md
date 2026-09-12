# Changelog

## 0.1.0-dev.3

- Add `PlatformAdvertisingIdSource`: Google's advertising ID on Android, read
  from Google Play services by the Android plugin, and the IDFA through App
  Tracking Transparency on iOS. An Android ID the user deleted or opted out of
  personalisation with is reported as `denied`, with no ID. Meant for developer
  tools, to register a phone as an ad test device.

## 0.1.0-dev.2

- **Breaking:** the Android vendor ID is now Google's app set ID, read by a new
  Android plugin, instead of `Build.ID`, which was shared by every phone on the
  same firmware. `VendorIdClient.androidId` is now `androidAppSetId`.
- Add `InstallMarker`, Android's first-install time.

## 0.1.0-dev.1

- Add `AttAdvertisingIdSource` and `DeviceInfoVendorIdSource` with injectable
  clients.
