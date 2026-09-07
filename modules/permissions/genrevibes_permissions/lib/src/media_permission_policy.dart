import 'model/permission_kind.dart';
import 'model/platform_facts.dart';

/// Which media permissions to ask for on a given platform.
final class MediaPermissionPolicy {
  /// Creates the policy.
  const MediaPermissionPolicy();

  /// Permissions needed to read the user's media library.
  ///
  /// Android 13 split the single storage permission into per-type grants;
  /// asking for `storage` there is a no-op that reads as denied. Older Android
  /// only understands `storage`. iOS uses the photo library for all of it.
  List<PermissionKind> mediaKindsFor(PlatformFacts platform) {
    if (platform.hasSplitMediaPermissions) {
      return const <PermissionKind>[
        PermissionKind.photos,
        PermissionKind.videos,
        PermissionKind.audio,
      ];
    }
    if (platform.isAndroid) {
      return const <PermissionKind>[PermissionKind.storage];
    }
    return const <PermissionKind>[PermissionKind.photos];
  }

  /// A broader permission worth offering when media access is denied.
  ///
  /// All-files access needs a manifest declaration and store review; offer it
  /// only where the app has both.
  PermissionKind? escalationFor(PlatformFacts platform) =>
      platform.isAndroid ? PermissionKind.manageExternalStorage : null;
}
