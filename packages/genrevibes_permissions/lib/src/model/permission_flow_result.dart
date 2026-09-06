import 'package:genrevibes_core/genrevibes_core.dart';

import 'permission_kind.dart';
import 'permission_state.dart';

/// Outcome of a permission flow.
enum PermissionFlowStatus {
  /// Every requested permission is usable.
  granted,

  /// At least one was denied and can be asked again.
  denied,

  /// At least one can only be changed from the settings screen.
  needsSettings,

  /// Asking again now would be a nag; wait for [PermissionFlowResult.retryAt].
  throttled,

  /// The provider failed.
  failed,
}

/// Result of a check or request across one or more permissions.
final class PermissionFlowResult {
  /// Creates a result.
  PermissionFlowResult({
    required this.status,
    required Map<PermissionKind, PermissionState> states,
    this.retryAt,
    this.error,
  }) : states = Map<PermissionKind, PermissionState>.unmodifiable(states);

  /// Aggregate outcome.
  final PermissionFlowStatus status;

  /// Per-permission state.
  final Map<PermissionKind, PermissionState> states;

  /// When a throttled request may be retried.
  final DateTime? retryAt;

  /// Provider failure, when [status] is [PermissionFlowStatus.failed].
  final KitError? error;

  /// Whether the feature may proceed.
  bool get isGranted => status == PermissionFlowStatus.granted;

  /// Permissions that are not usable.
  Iterable<PermissionKind> get missing =>
      states.entries.where((e) => !e.value.isUsable).map((e) => e.key);
}
