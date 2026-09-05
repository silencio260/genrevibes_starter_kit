/// Stable categories used to normalize errors from provider SDKs.
enum KitErrorCode {
  /// A module was used before successful initialization.
  notInitialized,

  /// Required configuration was absent or invalid.
  invalidConfiguration,

  /// The requested capability is temporarily unavailable.
  unavailable,

  /// The user or operating system denied permission.
  permissionDenied,

  /// The user cancelled an operation such as a purchase.
  cancelled,

  /// A network operation failed.
  network,

  /// A provider SDK reported an error.
  provider,

  /// The selected provider does not support the requested capability.
  unsupported,

  /// An operation exceeded its allowed duration.
  timeout,

  /// No more specific category could be determined.
  unknown,
}

/// A provider-neutral error safe to expose across package boundaries.
final class KitError implements Exception {
  /// Creates a normalized starter-kit error.
  const KitError({
    required this.code,
    required this.message,
    this.providerCode,
    this.cause,
    this.stackTrace,
    this.metadata = const <String, Object?>{},
  });

  /// The stable category applications can use for recovery decisions.
  final KitErrorCode code;

  /// A human-readable diagnostic message, not intended for direct UI display.
  final String message;

  /// The original vendor error code when one exists.
  final String? providerCode;

  /// The original error, retained for diagnostics.
  final Object? cause;

  /// The stack trace captured while mapping the original error.
  final StackTrace? stackTrace;

  /// Additional non-secret diagnostic fields.
  final Map<String, Object?> metadata;

  @override
  String toString() {
    final providerSuffix =
        providerCode == null ? '' : ', providerCode: $providerCode';
    return 'KitError(code: ${code.name}$providerSuffix, message: $message)';
  }
}
