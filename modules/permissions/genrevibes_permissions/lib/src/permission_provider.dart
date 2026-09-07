import 'package:genrevibes_core/genrevibes_core.dart';

import 'model/permission_kind.dart';
import 'model/permission_state.dart';
import 'model/platform_facts.dart';

/// Contract implemented by permission plugin adapters.
abstract interface class PermissionProvider implements StarterModule {
  /// Stable provider identifier, such as `permission_handler`.
  String get providerId;

  /// Platform facts, available after initialization.
  PlatformFacts get platform;

  /// Current state without prompting.
  Future<KitResult<PermissionState>> check(PermissionKind kind);

  /// Prompts the user and returns the resulting state.
  Future<KitResult<PermissionState>> request(PermissionKind kind);

  /// Opens the app's system settings page.
  Future<KitResult<bool>> openSettings();
}
