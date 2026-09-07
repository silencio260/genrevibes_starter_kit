import '../result/kit_result.dart';
import 'module_health.dart';

/// Common lifecycle contract implemented by starter-kit modules.
abstract interface class StarterModule {
  /// Stable module identifier used in diagnostics.
  String get moduleId;

  /// Most recent module health snapshot.
  ModuleHealth get health;

  /// Emits health changes, including initialization and failures.
  Stream<ModuleHealth> get healthChanges;

  /// Initializes the module. Repeated calls must be safe.
  Future<KitResult<void>> initialize();

  /// Releases resources. Repeated calls must be safe.
  Future<KitResult<void>> dispose();
}
