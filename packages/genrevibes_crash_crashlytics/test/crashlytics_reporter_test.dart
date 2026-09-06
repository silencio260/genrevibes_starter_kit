import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_crash/genrevibes_crash.dart';
import 'package:genrevibes_crash_crashlytics/genrevibes_crash_crashlytics.dart';
import 'package:genrevibes_crash_test/genrevibes_crash_test.dart';

void main() {
  runCrashReporterContractTests(
    reporterName: 'Crashlytics',
    createReporter: () async => CrashlyticsReporter(client: _FakeClient()),
  );

  group('CrashlyticsReporter mapping', () {
    test('routes a Flutter error payload to recordFlutterError', () async {
      final client = _FakeClient();
      final reporter = await _ready(client);
      final details = FlutterErrorDetails(exception: StateError('layout'));

      await reporter.record(CrashReport(error: details, fatal: true));

      expect(client.flutterErrors, hasLength(1));
      expect(client.dartErrors, isEmpty);
    });

    test('routes a Dart error with source and information', () async {
      final client = _FakeClient();
      final reporter = await _ready(client);

      await reporter.record(
        CrashReport(
          error: StateError('boom'),
          reason: 'loading feed',
          source: CrashSource.bloc,
          information: <String, Object?>{'screen': 'home'},
        ),
      );

      final recorded = client.dartErrors.single;
      expect(recorded.reason, 'loading feed');
      expect(recorded.information, contains('source: bloc'));
      expect(recorded.information, contains('screen: home'));
    });

    test('an SDK fault becomes a provider error and degrades health', () async {
      final client = _FakeClient();
      final reporter = await _ready(client);
      client.failWith = StateError('no firebase app');

      final result = await reporter.record(CrashReport(error: 'x'));

      expect(
        result.fold(onSuccess: (_) => null, onFailure: (e) => e.providerCode),
        'crashlytics_record',
      );
      expect(reporter.health.state, ModuleState.degraded);
    });
  });

  group('CrashHooks', () {
    test('installs and restores the framework handlers', () async {
      final client = _FakeClient();
      final coordinator = CrashCoordinator(
        reporter: CrashlyticsReporter(client: client),
        config: const CrashReportingConfig(collectionEnabled: true),
      );
      await coordinator.initialize();
      final before = FlutterError.onError;

      final handle = CrashHooks.install(coordinator);
      FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('paint')),
      );
      await Future<void>.delayed(Duration.zero);
      handle.restore();

      expect(client.flutterErrors, hasLength(1));
      expect(identical(FlutterError.onError, before), isTrue);
    });

    test('a guarded zone reports uncaught async errors', () async {
      final client = _FakeClient();
      final coordinator = CrashCoordinator(
        reporter: CrashlyticsReporter(client: client),
        config: const CrashReportingConfig(collectionEnabled: true),
      );
      await coordinator.initialize();

      CrashHooks.runGuarded(() {
        Future<void>.error(StateError('nobody awaited me'));
      }, coordinator);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(client.dartErrors.single.information, contains('source: zone'));
    });
  });
}

Future<CrashlyticsReporter> _ready(_FakeClient client) async {
  final reporter = CrashlyticsReporter(client: client);
  await reporter.initialize();
  return reporter;
}

final class _RecordedError {
  _RecordedError(this.reason, this.information, this.fatal);
  final String? reason;
  final List<String> information;
  final bool fatal;
}

final class _FakeClient implements CrashlyticsClient {
  Object? failWith;
  final List<bool> collection = <bool>[];
  final List<_RecordedError> dartErrors = <_RecordedError>[];
  final List<FlutterErrorDetails> flutterErrors = <FlutterErrorDetails>[];
  final List<String> logs = <String>[];
  String? userIdentifier;

  void _maybeThrow() {
    final error = failWith;
    if (error != null) throw error;
  }

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    _maybeThrow();
    collection.add(enabled);
  }

  @override
  Future<void> setUserIdentifier(String identifier) async {
    _maybeThrow();
    userIdentifier = identifier;
  }

  @override
  Future<void> setCustomKey(String key, Object value) async => _maybeThrow();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    Iterable<Object> information = const <Object>[],
    bool fatal = false,
  }) async {
    _maybeThrow();
    dartErrors.add(
      _RecordedError(reason, information.map((e) => '$e').toList(), fatal),
    );
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = true,
  }) async {
    _maybeThrow();
    flutterErrors.add(details);
  }

  @override
  Future<void> log(String message) async {
    _maybeThrow();
    logs.add(message);
  }
}
