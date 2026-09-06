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
    this.disposalOrder,
  }) : _health = ModuleHealth(
          moduleId: moduleId,
          state: ModuleState.idle,
          observedAt: DateTime(2026),
        );

  @override
  final String moduleId;
  final bool shouldFail;
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
