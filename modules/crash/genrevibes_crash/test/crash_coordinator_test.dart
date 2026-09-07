import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_crash/genrevibes_crash.dart';
import 'package:test/test.dart';

void main() {
  group('CrashCoordinator', () {
    test('applies the collection decision exactly once at startup', () async {
      final reporter = _FakeReporter();
      final coordinator = _coordinator(reporter, collect: false);

      await coordinator.initialize();
      await coordinator.initialize();

      expect(reporter.collectionCalls, <bool>[false]);
      expect(coordinator.health.state, ModuleState.ready);
    });

    test('rejects reports before initialization', () async {
      final coordinator = _coordinator(_FakeReporter());

      final result = await coordinator.report(CrashReport(error: 'x'));

      expect(
        result.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
        KitErrorCode.notInitialized,
      );
    });

    test('forwards a report and notifies the observer', () async {
      final reporter = _FakeReporter();
      final observer = _RecordingObserver();
      final coordinator = CrashCoordinator(
        reporter: reporter,
        config: const CrashReportingConfig(collectionEnabled: true),
        observer: observer,
      );
      await coordinator.initialize();

      await coordinator.report(
        CrashReport(error: StateError('boom'), fatal: true),
      );

      expect(reporter.reports, hasLength(1));
      expect(observer.seen, hasLength(1));
      expect(observer.seen.single.fatal, isTrue);
    });

    test('a failing reporter degrades health instead of throwing', () async {
      final reporter = _FakeReporter()..failRecord = true;
      final coordinator = _coordinator(reporter);
      await coordinator.initialize();

      final result = await coordinator.report(CrashReport(error: 'x'));

      expect(result.isFailure, isTrue);
      expect(coordinator.health.state, ModuleState.degraded);
    });

    test('a throwing observer never masks the report', () async {
      final reporter = _FakeReporter();
      final coordinator = CrashCoordinator(
        reporter: reporter,
        config: const CrashReportingConfig(collectionEnabled: true),
        observer: _ThrowingObserver(),
      );
      await coordinator.initialize();

      final result = await coordinator.report(CrashReport(error: 'x'));

      expect(result.isSuccess, isTrue);
      expect(reporter.reports, hasLength(1));
    });

    test('a reporter that fails to start fails initialization', () async {
      final coordinator = _coordinator(_FakeReporter()..failInitialize = true);

      expect((await coordinator.initialize()).isFailure, isTrue);
      expect(coordinator.health.state, ModuleState.failed);
    });

    test('identify and log delegate once ready', () async {
      final reporter = _FakeReporter();
      final coordinator = _coordinator(reporter);
      await coordinator.initialize();

      await coordinator.identify('install-1');
      await coordinator.log('opened settings');

      expect(reporter.userIdentifier, 'install-1');
      expect(reporter.logs, <String>['opened settings']);
    });

    test('disposal is idempotent', () async {
      final coordinator = _coordinator(_FakeReporter());
      await coordinator.initialize();

      expect((await coordinator.dispose()).isSuccess, isTrue);
      expect((await coordinator.dispose()).isSuccess, isTrue);
      expect(coordinator.health.state, ModuleState.disposed);
    });
  });

  group('CrashReport', () {
    test('copies its information map', () {
      final info = <String, Object?>{'screen': 'home'};
      final report = CrashReport(error: 'x', information: info);

      info['screen'] = 'settings';

      expect(report.information['screen'], 'home');
      expect(() => report.information.clear(), throwsUnsupportedError);
    });

    test('defaults to a non-fatal manual report', () {
      final report = CrashReport(error: 'x');

      expect(report.fatal, isFalse);
      expect(report.source, CrashSource.manual);
    });
  });
}

CrashCoordinator _coordinator(_FakeReporter reporter, {bool collect = true}) {
  return CrashCoordinator(
    reporter: reporter,
    config: CrashReportingConfig(collectionEnabled: collect),
  );
}

final class _RecordingObserver implements CrashObserver {
  final List<CrashReport> seen = <CrashReport>[];
  @override
  void onReported(CrashReport report) => seen.add(report);
}

final class _ThrowingObserver implements CrashObserver {
  @override
  void onReported(CrashReport report) => throw StateError('observer bug');
}

final class _FakeReporter implements CrashReporter {
  bool failInitialize = false;
  bool failRecord = false;
  final List<bool> collectionCalls = <bool>[];
  final List<CrashReport> reports = <CrashReport>[];
  final List<String> logs = <String>[];
  String? userIdentifier;
  ModuleState _state = ModuleState.idle;

  @override
  String get providerId => 'fake';
  @override
  String get moduleId => 'crash.fake';
  @override
  ModuleHealth get health => ModuleHealth(
        moduleId: moduleId,
        state: _state,
        observedAt: DateTime.utc(2026),
      );
  @override
  Stream<ModuleHealth> get healthChanges => const Stream<ModuleHealth>.empty();

  @override
  Future<KitResult<void>> initialize() async {
    if (failInitialize) {
      return const KitFailure<void>(
        KitError(code: KitErrorCode.provider, message: 'no firebase'),
      );
    }
    _state = ModuleState.ready;
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> setCollectionEnabled(bool enabled) async {
    collectionCalls.add(enabled);
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> setUserIdentifier(String identifier) async {
    userIdentifier = identifier;
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> setCustomKey(String key, Object value) async =>
      const KitSuccess<void>(null);

  @override
  Future<KitResult<void>> record(CrashReport report) async {
    if (failRecord) {
      return const KitFailure<void>(
        KitError(code: KitErrorCode.provider, message: 'record failed'),
      );
    }
    reports.add(report);
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> log(String message) async {
    logs.add(message);
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> dispose() async {
    _state = ModuleState.disposed;
    return const KitSuccess<void>(null);
  }
}
