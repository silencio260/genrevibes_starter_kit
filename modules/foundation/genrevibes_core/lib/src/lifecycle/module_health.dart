import '../error/kit_error.dart';

/// Lifecycle states shared by all starter-kit modules.
enum ModuleState {
  /// The application deliberately disabled the module.
  disabled,

  /// The module exists but has not started initialization.
  idle,

  /// Initialization is in progress.
  initializing,

  /// The module is ready for normal use.
  ready,

  /// The module is usable with reduced functionality.
  degraded,

  /// The module could not initialize or encountered a terminal failure.
  failed,

  /// The module released its resources and cannot be used.
  disposed,
}

/// An immutable diagnostic snapshot for a starter-kit module.
final class ModuleHealth {
  /// Creates a module health snapshot.
  const ModuleHealth({
    required this.moduleId,
    required this.state,
    required this.observedAt,
    this.provider,
    this.message,
    this.error,
    this.details = const <String, Object?>{},
  });

  /// Stable identifier such as `iap` or `analytics.firebase`.
  final String moduleId;

  /// Current lifecycle state.
  final ModuleState state;

  /// Time at which this snapshot was created.
  final DateTime observedAt;

  /// Selected vendor or implementation, when relevant.
  final String? provider;

  /// Optional diagnostic description.
  final String? message;

  /// Most recent normalized error.
  final KitError? error;

  /// Additional non-secret diagnostic fields.
  final Map<String, Object?> details;

  /// Whether the module can currently serve normal requests.
  bool get isOperational =>
      state == ModuleState.ready || state == ModuleState.degraded;
}
