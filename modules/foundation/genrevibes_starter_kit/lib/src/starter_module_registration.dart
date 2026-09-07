import 'package:genrevibes_core/genrevibes_core.dart';

/// Creates a module only when its registration is enabled.
typedef StarterModuleFactory = StarterModule Function();

/// Declares how one application-selected module participates in startup.
final class StarterModuleRegistration {
  /// Creates an enabled module registration.
  const StarterModuleRegistration.enabled({
    required this.moduleId,
    required this.create,
    this.isRequired = true,
  }) : enabled = true;

  /// Creates a disabled registration whose factory is never invoked.
  const StarterModuleRegistration.disabled({
    required this.moduleId,
    this.create,
  })  : enabled = false,
        isRequired = false;

  /// Stable ID expected from the created module.
  final String moduleId;

  /// Whether this application deliberately enabled the capability.
  final bool enabled;

  /// Whether a failure should make overall initialization fail.
  final bool isRequired;

  /// Lazy factory. Disabled registrations never invoke it.
  final StarterModuleFactory? create;
}
