import 'package:genrevibes_core/genrevibes_core.dart';

/// Per-sink result of an analytics pipeline operation.
final class AnalyticsDeliveryReport {
  /// Creates an analytics delivery report.
  const AnalyticsDeliveryReport({
    required this.operation,
    required this.attemptedSinks,
    required this.successfulSinks,
    required this.failures,
    this.suppressedByConsent = false,
  });

  /// Operation name or event name represented by this report.
  final String operation;

  /// Sink identifiers selected for delivery.
  final Set<String> attemptedSinks;

  /// Sink identifiers that completed successfully.
  final Set<String> successfulSinks;

  /// Failures keyed by sink identifier.
  final Map<String, KitError> failures;

  /// Whether the pipeline deliberately skipped delivery because of consent.
  final bool suppressedByConsent;

  /// Whether every attempted sink completed successfully.
  bool get isCompleteSuccess =>
      !suppressedByConsent &&
      attemptedSinks.isNotEmpty &&
      successfulSinks.length == attemptedSinks.length;

  /// Whether at least one sink received the operation.
  bool get wasDelivered => successfulSinks.isNotEmpty;
}
