import 'package:genrevibes_analytics/genrevibes_analytics.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:test/test.dart';

/// Creates a fresh analytics sink backed by a deterministic client.
typedef AnalyticsSinkFactory = Future<AnalyticsSink> Function();

/// Registers the behavior every analytics sink adapter must satisfy.
void runAnalyticsSinkContractTests({
  required String sinkName,
  required AnalyticsSinkFactory createSink,
}) {
  group('$sinkName analytics sink contract', () {
    late AnalyticsSink sink;

    setUp(() async => sink = await createSink());
    tearDown(() async => sink.dispose());

    test('initializes idempotently and reports ready health', () async {
      expect((await sink.initialize()).isSuccess, isTrue);
      expect((await sink.initialize()).isSuccess, isTrue);
      expect(sink.health.state, ModuleState.ready);
      expect(sink.sinkId, isNotEmpty);
    });

    test('accepts collection, event, identity, and profile operations',
        () async {
      expect((await sink.initialize()).isSuccess, isTrue);
      expect((await sink.setCollectionEnabled(true)).isSuccess, isTrue);
      expect(
        (await sink.track(
          const AnalyticsEvent(
            name: 'contract_event',
            properties: <String, Object?>{'source': 'contract'},
          ),
        ))
            .isSuccess,
        isTrue,
      );
      expect(
        (await sink.identify(
          const AnalyticsUser(
            id: 'portfolio-user-1',
            properties: <String, Object?>{'plan': 'pro'},
          ),
        ))
            .isSuccess,
        isTrue,
      );
      expect(
        (await sink.setUserProperties(const <String, Object?>{
          'cohort': 'retained',
        }))
            .isSuccess,
        isTrue,
      );
      expect((await sink.flush()).isSuccess, isTrue);
      expect((await sink.resetIdentity()).isSuccess, isTrue);
    });

    test('rejects event delivery before initialization', () async {
      final result = await sink.track(
        const AnalyticsEvent(name: 'too_early'),
      );
      expect(result.isFailure, isTrue);
      expect(
        result.fold(
          onSuccess: (_) => null,
          onFailure: (error) => error.code,
        ),
        KitErrorCode.notInitialized,
      );
    });
  });
}
