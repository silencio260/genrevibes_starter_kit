import 'model/permission_kind.dart';

/// Storage keys used by [PermissionCoordinator].
abstract final class PermissionKeys {
  /// How many times [kind] has been requested.
  static String requestCount(PermissionKind kind) =>
      'genrevibes.permissions.${kind.name}.request_count.v1';

  /// When [kind] was last requested, in milliseconds since epoch.
  static String lastRequestedAt(PermissionKind kind) =>
      'genrevibes.permissions.${kind.name}.last_requested_at.v1';
}
