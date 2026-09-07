import 'model/permission_flow_result.dart';
import 'model/permission_kind.dart';

/// Receives permission flow events for analytics.
abstract interface class PermissionObserver {
  /// A request is about to be shown.
  void onRequested(List<PermissionKind> kinds);

  /// A flow finished.
  void onResolved(PermissionFlowResult result);
}

/// [PermissionObserver] that records nothing.
final class NoopPermissionObserver implements PermissionObserver {
  /// Creates a no-op observer.
  const NoopPermissionObserver();

  @override
  void onRequested(List<PermissionKind> kinds) {}

  @override
  void onResolved(PermissionFlowResult result) {}
}
