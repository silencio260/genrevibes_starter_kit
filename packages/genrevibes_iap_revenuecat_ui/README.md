# genrevibes_iap_revenuecat_ui

Optional RevenueCat paywall and customer-center presentation for
`genrevibes_iap_revenuecat`.

Install this package only when an application uses RevenueCat-hosted UI. Apps
that render their own paywall need only `genrevibes_iap_revenuecat` and do not
receive the `purchases_ui_flutter` dependency.

```dart
final iap = RevenueCatIapProvider(
  configuration: const RevenueCatConfiguration(
    androidApiKey: String.fromEnvironment('REVENUECAT_ANDROID_API_KEY'),
    iosApiKey: String.fromEnvironment('REVENUECAT_IOS_API_KEY'),
  ),
  uiPresenter: const RevenueCatUiAdapter(displayCloseButton: true),
);
```

The API is experimental until the first stable release.

See [`example/main.dart`](example/main.dart) for initialization, entitlement
observation, hosted paywall, and restore composition. Supply public SDK keys at
build time rather than committing them:

```shell
flutter run \
  --dart-define=REVENUECAT_ANDROID_API_KEY=your_public_android_sdk_key \
  --dart-define=REVENUECAT_IOS_API_KEY=your_public_ios_sdk_key
```
