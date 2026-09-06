import 'package:permission_handler/permission_handler.dart' as ph;

/// Injectable boundary around the permission_handler plugin.
abstract interface class PermissionHandlerClient {
  /// Current status without prompting.
  Future<ph.PermissionStatus> status(ph.Permission permission);

  /// Prompts and returns the resulting status.
  Future<ph.PermissionStatus> request(ph.Permission permission);

  /// Opens the app's system settings page.
  Future<bool> openAppSettings();
}

/// Production client.
final class DefaultPermissionHandlerClient implements PermissionHandlerClient {
  /// Creates a client over the plugin's static API.
  const DefaultPermissionHandlerClient();

  @override
  Future<ph.PermissionStatus> status(ph.Permission permission) =>
      permission.status;

  @override
  Future<ph.PermissionStatus> request(ph.Permission permission) =>
      permission.request();

  @override
  Future<bool> openAppSettings() => ph.openAppSettings();
}
