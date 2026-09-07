import 'package:genrevibes_core/genrevibes_core.dart';

/// Contract implemented by URL, email and share adapters.
abstract interface class LinkOpener implements StarterModule {
  /// Stable provider identifier, such as `url_launcher`.
  String get providerId;

  /// Opens [uri], in an external application by default.
  Future<KitResult<void>> openUrl(Uri uri, {bool external = true});

  /// Opens the mail client with a prefilled message.
  Future<KitResult<void>> openEmail({
    required String to,
    String? subject,
    String? body,
  });

  /// Opens the platform share sheet.
  Future<KitResult<void>> share({required String text, String? subject});
}
