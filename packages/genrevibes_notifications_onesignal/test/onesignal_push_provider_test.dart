import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_notifications/genrevibes_notifications.dart';
import 'package:genrevibes_notifications_onesignal/genrevibes_notifications_onesignal.dart';

void main() {
  test('initialization is idempotent and observers are attached once',
      () async {
    final client = _FakeOneSignalClient();
    final provider = OneSignalPushProvider(
      configuration: const GenreVibesOneSignalConfiguration(appId: 'test-app'),
      client: client,
    );

    expect((await provider.initialize()).isSuccess, isTrue);
    expect((await provider.initialize()).isSuccess, isTrue);
    expect(client.initializeCalls, 1);
    expect(client.listenerAdds, 4);

    await provider.dispose();
    expect(client.listenerRemoves, 4);
  });

  test('exposes independent subscription diagnostics', () async {
    final client = _FakeOneSignalClient(
      state: const OneSignalClientState(
        permission: OneSignalClientPermission.authorized,
        canRequestPermission: false,
        optedIn: false,
        subscriptionId: 'subscription',
        pushToken: 'token',
      ),
    );
    final provider = OneSignalPushProvider(
      configuration: const GenreVibesOneSignalConfiguration(appId: 'test-app'),
      client: client,
    );
    await provider.initialize();

    final result = await provider.getSubscriptionState();
    result.fold(
      onSuccess: (state) {
        expect(state.issues, <PushDeliveryIssue>{
          PushDeliveryIssue.providerOptedOut,
        });
        expect(provider.health.details['hasPushToken'], isTrue);
        expect(provider.health.details.toString(), isNot(contains('token')));
      },
      onFailure: (error) => fail(error.toString()),
    );
  });

  test('emits foreground, open, and observed state changes', () async {
    final client = _FakeOneSignalClient();
    final provider = OneSignalPushProvider(
      configuration: const GenreVibesOneSignalConfiguration(appId: 'test-app'),
      client: client,
    );
    await provider.initialize();
    final events = <PushEvent>[];
    final subscription = provider.events.listen(events.add);

    client.emitForeground(const OneSignalClientMessage(id: 'received'));
    client.emitClick(
      const OneSignalClientMessage(id: 'opened', actionId: 'view'),
    );
    client.emitSubscriptionChanged();
    await pumpEventQueue();

    expect(events.whereType<PushMessageReceived>(), hasLength(1));
    expect(
        events.whereType<PushMessageOpened>().single.message.actionId, 'view');
    expect(events.whereType<PushStateChanged>(), hasLength(1));
    await subscription.cancel();
    await provider.dispose();
  });
}

final class _FakeOneSignalClient implements OneSignalClient {
  _FakeOneSignalClient({
    this.state = const OneSignalClientState(
      permission: OneSignalClientPermission.denied,
      canRequestPermission: true,
      optedIn: false,
    ),
  });

  OneSignalClientState state;
  int initializeCalls = 0;
  int listenerAdds = 0;
  int listenerRemoves = 0;
  OneSignalStateListener? permissionListener;
  OneSignalStateListener? subscriptionListener;
  OneSignalMessageListener? foregroundListener;
  OneSignalMessageListener? clickListener;

  void emitSubscriptionChanged() => subscriptionListener?.call();
  void emitForeground(OneSignalClientMessage message) =>
      foregroundListener?.call(message);
  void emitClick(OneSignalClientMessage message) =>
      clickListener?.call(message);

  @override
  void addClickListener(OneSignalMessageListener listener) {
    listenerAdds++;
    clickListener = listener;
  }

  @override
  void addForegroundListener(OneSignalMessageListener listener) {
    listenerAdds++;
    foregroundListener = listener;
  }

  @override
  void addPermissionListener(OneSignalStateListener listener) {
    listenerAdds++;
    permissionListener = listener;
  }

  @override
  void addSubscriptionListener(OneSignalStateListener listener) {
    listenerAdds++;
    subscriptionListener = listener;
  }

  @override
  Future<void> configurePrivacy({
    required bool consentRequired,
    required bool? consentGranted,
  }) async {}

  @override
  Future<OneSignalClientState> getState() async => state;

  @override
  void initialize(String appId) => initializeCalls++;

  @override
  Future<void> login(String externalUserId) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> optIn() async {}

  @override
  Future<void> optOut() async {}

  @override
  void removeClickListener(OneSignalMessageListener listener) {
    listenerRemoves++;
    clickListener = null;
  }

  @override
  void removeForegroundListener(OneSignalMessageListener listener) {
    listenerRemoves++;
    foregroundListener = null;
  }

  @override
  void removePermissionListener(OneSignalStateListener listener) {
    listenerRemoves++;
    permissionListener = null;
  }

  @override
  void removeSubscriptionListener(OneSignalStateListener listener) {
    listenerRemoves++;
    subscriptionListener = null;
  }

  @override
  Future<void> removeTags(List<String> keys) async {}

  @override
  Future<void> requestPermission({required bool fallbackToSettings}) async {}

  @override
  Future<void> setTags(Map<String, String> tags) async {}

  @override
  Future<void> setVerboseLogging(bool enabled) async {}
}
