import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_starter_kit/genrevibes_starter_kit.dart';
import 'package:test/test.dart';

void main() {
  test('disabled module factory is never invoked', () async {
    var created = false;
    final kit = GenRevibesStarterKit(
      modules: <StarterModuleRegistration>[
        StarterModuleRegistration.disabled(
          moduleId: 'analytics.posthog',
          create: () {
            created = true;
            return _FakeModule('analytics.posthog');
          },
        ),
        StarterModuleRegistration.enabled(
          moduleId: 'core.test',
          create: () => _FakeModule('core.test'),
        ),
      ],
    );

    expect((await kit.initialize()).isSuccess, isTrue);
    expect(created, isFalse);
    expect(kit.modules.keys, <String>['core.test']);
  });

  test('optional failure degrades without blocking healthy modules', () async {
    final healthy = _FakeModule('healthy');
    final kit = GenRevibesStarterKit(
      modules: <StarterModuleRegistration>[
        StarterModuleRegistration.enabled(
          moduleId: 'optional',
          isRequired: false,
          create: () => _FakeModule('optional', shouldFail: true),
        ),
        StarterModuleRegistration.enabled(
          moduleId: 'healthy',
          create: () => healthy,
        ),
      ],
    );

    expect((await kit.initialize()).isSuccess, isTrue);
    expect(healthy.initializeCalls, 1);
    expect(kit.health.state, ModuleState.degraded);
  });

  test('required failure is returned after independent modules are attempted',
      () async {
    final healthy = _FakeModule('healthy');
    final kit = GenRevibesStarterKit(
      modules: <StarterModuleRegistration>[
        StarterModuleRegistration.enabled(
          moduleId: 'required',
          create: () => _FakeModule('required', shouldFail: true),
        ),
        StarterModuleRegistration.enabled(
          moduleId: 'healthy',
          create: () => healthy,
        ),
      ],
    );

    expect((await kit.initialize()).isFailure, isTrue);
    expect(healthy.initializeCalls, 1);
    expect(kit.health.state, ModuleState.failed);
  });

  test('concurrent initialization coalesces and disposal runs in reverse',
      () async {
    final order = <String>[];
    final first = _FakeModule('first', disposalOrder: order);
    final second = _FakeModule('second', disposalOrder: order);
    final kit = GenRevibesStarterKit(
      modules: <StarterModuleRegistration>[
        StarterModuleRegistration.enabled(
          moduleId: 'first',
          create: () => first,
        ),
        StarterModuleRegistration.enabled(
          moduleId: 'second',
          create: () => second,
        ),
      ],
    );

    await Future.wait(<Future<KitResult<void>>>[
      kit.initialize(),
      kit.initialize(),
    ]);
    expect(first.initializeCalls, 1);
    expect(second.initializeCalls, 1);

    await kit.dispose();
    expect(order, <String>['second', 'first']);
  });

  test('a module that never settles times out instead of hanging startup',
      () async {
    final healthy = _FakeModule('healthy');
    final kit = GenRevibesStarterKit(
      moduleTimeout: const Duration(milliseconds: 50),
      modules: <StarterModuleRegistration>[
        StarterModuleRegistration.enabled(
          moduleId: 'stalled',
          isRequired: false,
          create: () => _FakeModule('stalled', stalls: true),
        ),
        StarterModuleRegistration.enabled(
          moduleId: 'healthy',
          create: () => healthy,
        ),
      ],
    );

    final result = await kit.initialize().timeout(const Duration(seconds: 5));

    // The stalled module is optional, so startup succeeds without it and the
    // module behind it still runs. Before the timeout existed, this call never
    // returned and the application stopped at the launch screen with no error,
    // no log and an empty Dart stack.
    expect(result.isSuccess, isTrue);
    expect(healthy.initializeCalls, 1);
    expect(kit.health.state, ModuleState.degraded);
  });

  test('a required module that never settles fails the report', () async {
    final kit = GenRevibesStarterKit(
      moduleTimeout: const Duration(milliseconds: 50),
      modules: <StarterModuleRegistration>[
        StarterModuleRegistration.enabled(
          moduleId: 'stalled',
          create: () => _FakeModule('stalled', stalls: true),
        ),
      ],
    );

    final result = await kit.initialize().timeout(const Duration(seconds: 5));

    expect(result.isFailure, isTrue);
    expect(
      result.fold(onSuccess: (_) => null, onFailure: (error) => error.code),
      KitErrorCode.timeout,
    );
  });

  test('an adapter may name itself under the capability it implements',
      () async {
    // AdMobAdProvider reports `ads.admob` for an `ads` registration, and
    // OneSignalPushProvider `notifications.push.onesignal` for
    // `notifications.push`. Requiring exact equality made registering any
    // such adapter impossible, which silently disabled ads and push on
    // device while every other module reported ready.
    final kit = GenRevibesStarterKit(
      modules: <StarterModuleRegistration>[
        StarterModuleRegistration.enabled(
          moduleId: 'ads',
          create: () => _FakeModule('ads.admob'),
        ),
      ],
    );

    expect((await kit.initialize()).isSuccess, isTrue);
    // Keyed by the registration, so lookups do not need to know the vendor.
    expect(kit.modules.keys, <String>['ads']);
    expect(kit.health.state, ModuleState.ready);
  });

  test('an unrelated module is still a configuration error', () async {
    final kit = GenRevibesStarterKit(
      modules: <StarterModuleRegistration>[
        StarterModuleRegistration.enabled(
          moduleId: 'ads',
          create: () => _FakeModule('analytics'),
        ),
      ],
    );

    final result = await kit.initialize();
    expect(result.isFailure, isTrue);
    expect(
      result.fold(onSuccess: (_) => null, onFailure: (error) => error.code),
      KitErrorCode.invalidConfiguration,
    );
  });

  test('rejects duplicate module ids before creating providers', () async {
    var createCalls = 0;
    final kit = GenRevibesStarterKit(
      modules: <StarterModuleRegistration>[
        for (var index = 0; index < 2; index++)
          StarterModuleRegistration.enabled(
            moduleId: 'duplicate',
            create: () {
              createCalls++;
              return _FakeModule('duplicate');
            },
          ),
      ],
    );

    expect((await kit.initialize()).isFailure, isTrue);
    expect(createCalls, 0);
  });
}

final class _FakeModule implements StarterModule {
  _FakeModule(
    this.moduleId, {
    this.shouldFail = false,
    this.stalls = false,
    this.disposalOrder,
  }) : _health = ModuleHealth(
          moduleId: moduleId,
          state: ModuleState.idle,
          observedAt: DateTime(2026),
        );

  @override
  final String moduleId;
  final bool shouldFail;

  /// Never settles, the way a vendor SDK whose callback never fires behaves.
  final bool stalls;
  final List<String>? disposalOrder;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  ModuleHealth _health;
  int initializeCalls = 0;

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  Future<KitResult<void>> initialize() async {
    initializeCalls++;
    if (stalls) return Completer<KitResult<void>>().future;
    if (shouldFail) {
      const error = KitError(
        code: KitErrorCode.provider,
        message: 'fixture failure',
      );
      _setHealth(ModuleState.failed, error: error);
      return const KitFailure<void>(error);
    }
    _setHealth(ModuleState.ready);
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> dispose() async {
    disposalOrder?.add(moduleId);
    _setHealth(ModuleState.disposed);
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      state: state,
      observedAt: DateTime(2026),
      error: error,
    );
    _healthChanges.add(_health);
  }
}
