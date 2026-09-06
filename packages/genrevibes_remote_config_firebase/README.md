# genrevibes_remote_config_firebase

Firebase implementation of `RemoteConfigProvider`. The app owns Firebase
initialization. During adapter initialization, existing activated Firebase
values are exposed as provider-cache values before any network fetch. Failed
fetches return an error without replacing the previous snapshot.

The current Story Saver ad settings can be composed without exposing Firebase
types to monetization code:

```dart
final firstInterstitial = RemoteConfigKey<int>(
  name: 'time_before_first_insta_ad',
  defaultValue: 3,
  codec: const RemoteConfigIntCodec(),
  isValid: (value) => value >= 0,
);

final schema = RemoteConfigSchema([
  remoteConfigKey(firstInterstitial),
]);
final provider = GenRevibesFirebaseRemoteConfigProvider(schema: schema);
final config = RemoteConfigCoordinator(
  schema: schema,
  provider: provider,
  cache: SharedPreferencesRemoteConfigCache(), // optional package
);

await config.initialize();
await config.refresh();
final interval = config.current.read(firstInterstitial);
```

The application must initialize Firebase before creating the default client.
