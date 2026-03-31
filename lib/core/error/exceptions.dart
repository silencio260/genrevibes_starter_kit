/// Base exception class for StarterKit
class StarterKitException implements Exception {
  final String message;
  final dynamic originalError;

  const StarterKitException({required this.message, this.originalError});

  @override
  String toString() => 'StarterKitException: $message';
}

/// Network exception
class NetworkException extends StarterKitException {
  const NetworkException({String message = 'Network error'})
    : super(message: message);
}

/// Server exception
class ServerException extends StarterKitException {
  final int? statusCode;

  const ServerException({String message = 'Server error', this.statusCode})
    : super(message: message);
}

/// Configuration exception
class ConfigurationException extends StarterKitException {
  const ConfigurationException({String message = 'Configuration error'})
    : super(message: message);
}

/// Purchase exception
class PurchaseException extends StarterKitException {
  const PurchaseException({required String message}) : super(message: message);
}

/// Ad exception
class AdException extends StarterKitException {
  const AdException({required String message}) : super(message: message);
}
