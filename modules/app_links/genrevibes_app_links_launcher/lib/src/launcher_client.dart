import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Injectable boundary around url_launcher and share_plus.
abstract interface class LauncherClient {
  /// Whether [uri] has a handler.
  Future<bool> canLaunch(Uri uri);

  /// Launches [uri]; returns whether it was handed off.
  Future<bool> launch(Uri uri, {required bool external});

  /// Opens the share sheet.
  Future<void> share(String text, {String? subject});
}

/// Production client.
final class DefaultLauncherClient implements LauncherClient {
  /// Creates a client.
  const DefaultLauncherClient();

  @override
  Future<bool> canLaunch(Uri uri) => canLaunchUrl(uri);

  @override
  Future<bool> launch(Uri uri, {required bool external}) => launchUrl(
        uri,
        mode: external
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      );

  @override
  Future<void> share(String text, {String? subject}) =>
      Share.share(text, subject: subject);
}
