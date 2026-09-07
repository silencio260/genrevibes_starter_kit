import 'package:genrevibes_permissions/genrevibes_permissions.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// The plugin permission for a neutral [PermissionKind].
ph.Permission permissionFor(PermissionKind kind) => switch (kind) {
      PermissionKind.photos => ph.Permission.photos,
      PermissionKind.videos => ph.Permission.videos,
      PermissionKind.audio => ph.Permission.audio,
      PermissionKind.storage => ph.Permission.storage,
      PermissionKind.manageExternalStorage =>
        ph.Permission.manageExternalStorage,
      PermissionKind.notifications => ph.Permission.notification,
      PermissionKind.camera => ph.Permission.camera,
      PermissionKind.microphone => ph.Permission.microphone,
      PermissionKind.location => ph.Permission.locationWhenInUse,
    };

/// The neutral state for a plugin status.
PermissionState mapPermissionStatus(ph.PermissionStatus status) =>
    switch (status) {
      ph.PermissionStatus.granted => PermissionState.granted,
      ph.PermissionStatus.limited => PermissionState.limited,
      ph.PermissionStatus.provisional => PermissionState.provisional,
      ph.PermissionStatus.denied => PermissionState.denied,
      ph.PermissionStatus.permanentlyDenied =>
        PermissionState.permanentlyDenied,
      ph.PermissionStatus.restricted => PermissionState.restricted,
    };
