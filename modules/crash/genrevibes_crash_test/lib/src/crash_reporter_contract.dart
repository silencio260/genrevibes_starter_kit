import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_crash/genrevibes_crash.dart';
import 'package:test/test.dart';

/// Creates a fresh crash reporter backed by a deterministic client.
typedef CrashReporterFactory = Future<CrashReporter> Function();

/// Registers the behavior every crash reporter adapter must satisfy.
void runCrashReporterContractTests({
  required String reporterName,
  required CrashReporterFactory createReporter,
}) {
  group('$reporterName crash reporter contract', () {
    late CrashReporter reporter;

    setUp(() async => reporter = await createReporter());
    tearDown(() async => reporter.dispose());

    test('reports a stable non-empty provider identifier', () {
      expect(reporter.providerId, isNotEmpty);
    });

    test('rejects work before initialization', () async {
      final result = await reporter.record(CrashReport(error: 'x'));

      expect(
        result.fold(onSuccess: (_) => null, onFailure: (error) => error.code),
        KitErrorCode.notInitialized,
      );
    });

    test('becomes ready after initialization, idempotently', () async {
      expect((await reporter.initialize()).isSuccess, isTrue);
      expect((await reporter.initialize()).isSuccess, isTrue);
      expect(reporter.health.state, ModuleState.ready);
    });

    test('records a report once ready', () async {
      await reporter.initialize();

      final result = await reporter.record(
        CrashReport(error: StateError('boom'), stackTrace: StackTrace.current),
      );

      expect(result.isSuccess, isTrue);
    });

    test('recording still succeeds while collection is disabled', () async {
      // Disabled means "do not send", never "fail the caller". A reporter that
      // errors inside an error handler masks the original crash.
      await reporter.initialize();
      await reporter.setCollectionEnabled(false);

      expect(
          (await reporter.record(CrashReport(error: 'x'))).isSuccess, isTrue);
    });

    test('identity, custom keys and breadcrumbs succeed once ready', () async {
      await reporter.initialize();

      expect((await reporter.setUserIdentifier('u1')).isSuccess, isTrue);
      expect((await reporter.setCustomKey('screen', 'home')).isSuccess, isTrue);
      expect((await reporter.log('breadcrumb')).isSuccess, isTrue);
    });

    test('disposal is idempotent and reports disposed health', () async {
      await reporter.initialize();

      expect((await reporter.dispose()).isSuccess, isTrue);
      expect((await reporter.dispose()).isSuccess, isTrue);
      expect(reporter.health.state, ModuleState.disposed);
    });
  });
}
