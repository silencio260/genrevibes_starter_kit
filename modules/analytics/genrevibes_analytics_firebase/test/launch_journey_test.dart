import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_analytics_firebase/genrevibes_analytics_firebase.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<(String, Map<String, Object?>)> sent;
  void send(String name, Map<String, Object?> properties) =>
      sent.add((name, properties));
  List<String> names() => [for (final (name, _) in sent) name];

  setUp(() => sent = []);

  LaunchJourney started({String? install = 'install-1'}) {
    final journey = LaunchJourney.forTesting(appInstanceId: () async => install)
      ..start();
    addTearDown(journey.dispose);
    return journey;
  }

  test('first launch: holds events, then numbers and prefixes them', () async {
    final journey = started();
    journey.deliver('sign_up', {'method': 'google'}, send);
    expect(sent, isEmpty, reason: 'held until attach');

    await journey.attach(
      send: send,
      store: MemoryKeyValueStore(),
      alreadyOnboarded: false,
      testDevice: false,
    );

    expect(journey.launchNumber, 1);
    expect(names(), ['app_launch', 'l1_app_launch', 'sign_up', 'l1_sign_up']);
    expect(sent[2].$2, {'method': 'google', 'launch_number': 1});
  });

  test('home ends the prefixed path', () async {
    final journey = started();
    await journey.attach(
      send: send,
      store: MemoryKeyValueStore(),
      alreadyOnboarded: false,
      testDevice: false,
    );
    journey.screenShown('tab_home');
    sent.clear();

    journey.deliver('mining_started', const {}, send);

    expect(names(), ['mining_started']);
    expect(journey.beforeHome, isFalse);
  });

  test('revenue is never copied', () async {
    final journey = started();
    await journey.attach(
      send: send,
      store: MemoryKeyValueStore(),
      alreadyOnboarded: false,
      testDevice: false,
    );
    sent.clear();

    journey.deliver('ad_impression', {'value': 0.01, 'currency': 'USD'}, send);
    journey.deliver('purchase', {'value': 1, 'currency': 'USD'}, send);

    expect(names(), ['ad_impression', 'purchase', 'l1_purchase']);
    expect(sent.last.$2.containsKey('value'), isFalse);
  });

  test('an upgraded install starts past the prefixed launches', () async {
    final journey = started();
    await journey.attach(
      send: send,
      store: MemoryKeyValueStore(),
      alreadyOnboarded: true,
      testDevice: false,
    );

    expect(journey.launchNumber, 3);
    expect(names(), ['app_launch'], reason: 'no l3_ copies');
  });

  test('counts launches and reports an abandoned previous launch', () async {
    final store = MemoryKeyValueStore();
    final first = started();
    await first.attach(
      send: send,
      store: store,
      alreadyOnboarded: false,
      testDevice: false,
    );
    first.screenShown('language_select');
    await Future<void>.delayed(Duration.zero);
    sent.clear();

    final second = started();
    await second.attach(
      send: send,
      store: store,
      alreadyOnboarded: false,
      testDevice: false,
    );

    expect(second.launchNumber, 2);
    final abandoned =
        sent.firstWhere((e) => e.$1 == 'previous_launch_abandoned').$2;
    expect(abandoned['previous_launch'], 1);
    expect(abandoned['step_reached'], 'language_select_shown');
  });

  test('a restored backup on a new install starts again at 1', () async {
    final store = MemoryKeyValueStore();
    await started(install: 'old').attach(
      send: send,
      store: store,
      alreadyOnboarded: false,
      testDevice: false,
    );
    await Future<void>.delayed(Duration.zero);

    final fresh = started(install: 'new');
    await fresh.attach(
      send: send,
      store: store,
      alreadyOnboarded: true,
      testDevice: false,
    );

    expect(fresh.launchNumber, 1);
  });

  test('sends nothing on a Google test device', () async {
    final journey = started();
    journey.deliver('sign_up', const {}, send);
    await journey.attach(
      send: send,
      store: MemoryKeyValueStore(),
      alreadyOnboarded: false,
      testDevice: true,
    );
    journey
      ..step('startup_runtime_ready')
      ..deliver('login', const {}, send);

    expect(sent, isEmpty);
  });
}
