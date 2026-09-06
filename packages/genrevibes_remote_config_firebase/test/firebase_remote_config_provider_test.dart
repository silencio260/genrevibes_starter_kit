import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';
import 'package:genrevibes_remote_config_firebase/genrevibes_remote_config_firebase.dart';

void main() {
  final intervalKey = RemoteConfigKey<int>(
    name: 'ad_interval',
    defaultValue: 3,
    codec: const RemoteConfigIntCodec(),
    isValid: (value) => value >= 0,
  );
  final schema = RemoteConfigSchema(<RemoteConfigKey<Object?>>[
    remoteConfigKey(intervalKey),
  ]);

  test('loads provider-persisted values during initialization', () async {
    final client = _FakeFirebaseClient()
      ..values = <String, Object?>{'ad_interval': 6};
    final provider = GenRevibesFirebaseRemoteConfigProvider(
      schema: schema,
      client: client,
    );

    expect((await provider.initialize()).isSuccess, isTrue);
    expect(provider.current.values['ad_interval'], 6);
    expect(
      provider.current.originOf('ad_interval'),
      RemoteConfigValueOrigin.providerCache,
    );
  });

  test('refresh returns newly activated values', () async {
    final client = _FakeFirebaseClient();
    final provider = GenRevibesFirebaseRemoteConfigProvider(
      schema: schema,
      client: client,
    );
    await provider.initialize();
    client.values = <String, Object?>{'ad_interval': 10};

    final result = await provider.refresh();

    expect(result.isSuccess, isTrue);
    expect(provider.current.values['ad_interval'], 10);
    expect(
      provider.current.originOf('ad_interval'),
      RemoteConfigValueOrigin.remote,
    );
  });

  test('fetch failure preserves the previously activated snapshot', () async {
    final client = _FakeFirebaseClient()
      ..values = <String, Object?>{'ad_interval': 6};
    final provider = GenRevibesFirebaseRemoteConfigProvider(
      schema: schema,
      client: client,
    );
    await provider.initialize();
    client.fetchError = StateError('offline');

    expect((await provider.refresh()).isFailure, isTrue);
    expect(provider.current.values['ad_interval'], 6);
  });
}

final class _FakeFirebaseClient implements FirebaseRemoteConfigClient {
  Map<String, Object?> values = <String, Object?>{'ad_interval': 3};
  Object? fetchError;

  @override
  Future<bool> fetchAndActivate() async {
    final error = fetchError;
    if (error != null) throw error;
    return true;
  }

  @override
  FirebaseRemoteConfigReadResult read(
    RemoteConfigSchema schema, {
    required RemoteConfigValueOrigin remoteOrigin,
  }) {
    return FirebaseRemoteConfigReadResult(
      values: values,
      origins: <String, RemoteConfigValueOrigin>{
        for (final key in values.keys) key: remoteOrigin,
      },
    );
  }

  @override
  Future<void> setup(
    GenRevibesFirebaseRemoteConfigConfiguration configuration,
    Map<String, Object> defaults,
  ) async {}
}
