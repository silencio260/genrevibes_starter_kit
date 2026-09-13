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
    this.timeout,
  })  : enabled = true,
        isDeferred = false;

  /// Creates a module that starts after `initialize()` has returned.
  ///
  /// Starts in a separate ordered sequence, bounded by [timeout] or the
  /// coordinator's default. Failure or timeout still starts the next entry.
  /// For UI prompts, disable automatic deferred startup on the coordinator and
  /// call startDeferred after a frame is rendered.
  ///
  /// A deferred module cannot be required: initialization has already been
  /// reported by the time it runs.
  const StarterModuleRegistration.deferred({
    required this.moduleId,
    required this.create,
    this.timeout,
  })  : enabled = true,
        isRequired = false,
        isDeferred = true;

  /// Creates a disabled registration whose factory is never invoked.
  const StarterModuleRegistration.disabled({
    required this.moduleId,
    this.create,
  })  : timeout = null,
        enabled = false,
        isRequired = false,
        isDeferred = false;

  /// Overrides the coordinator timeout for this module, including deferred work.
  final Duration? timeout;

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
