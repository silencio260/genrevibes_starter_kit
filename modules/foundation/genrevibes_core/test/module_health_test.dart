import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:test/test.dart';

void main() {
  test('ready and degraded modules are operational', () {
    final observedAt = DateTime.utc(2026);

    for (final state in <ModuleState>[
      ModuleState.ready,
      ModuleState.degraded,
    ]) {
      expect(
        ModuleHealth(
          moduleId: 'test',
          state: state,
          observedAt: observedAt,
        ).isOperational,
        isTrue,
      );
    }
  });

  test('failed modules are not operational', () {
    final health = ModuleHealth(
      moduleId: 'test',
      state: ModuleState.failed,
      observedAt: DateTime.utc(2026),
    );

    expect(health.isOperational, isFalse);
  });
}
