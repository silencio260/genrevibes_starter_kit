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
  })  : enabled = true,
        isDeferred = false;

  /// Creates a module that starts after `initialize()` has returned.
  ///
  /// Some capabilities are slow and nothing else depends on them. Consent is
  /// the clearest case: it may present a form and wait for a person to dismiss
  /// it, which can take seconds or minutes, and running that in the startup
  /// chain holds back every module behind it and the first frame with them.
  ///
  /// Deferred modules are created and health-tracked like any other, but the
  /// coordinator does not wait for them. They start in registration order, in
  /// one background sequence, so a deferred module can still depend on the one
  /// declared before it.
  ///
  /// A deferred module cannot be required: initialization has already been
  /// reported by the time it runs.
  const StarterModuleRegistration.deferred({
    required this.moduleId,
    required this.create,
  })  : enabled = true,
        isRequired = false,
        isDeferred = true;

  /// Creates a disabled registration whose factory is never invoked.
  const StarterModuleRegistration.disabled({
    required this.moduleId,
    this.create,
  })  : enabled = false,
        isRequired = false,
        isDeferred = false;

  /// Stable ID expected from the created module.
  final String moduleId;

  /// Whether this application deliberately enabled the capability.
  final bool enabled;

  /// Whether a failure should make overall initialization fail.
  final bool isRequired;

  /// Whether this module starts after `initialize()` returns.
  final bool isDeferred;

  /// Lazy factory. Disabled registrations never invoke it.
  final StarterModuleFactory? create;
}
