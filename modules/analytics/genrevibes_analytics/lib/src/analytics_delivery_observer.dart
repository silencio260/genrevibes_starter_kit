import 'model/analytics_delivery_report.dart';
import 'model/analytics_event.dart';

/// Watches what the pipeline delivered, and to which sinks.
///
/// [AnalyticsPipeline] returns an [AnalyticsDeliveryReport] to whoever called
/// it, which is enough to check one call. It is not enough to see what an
/// application actually emits while it runs: the events that matter most are
/// fired deep inside features, and their reports are discarded at the call
/// site.
///
/// An observer sees every dispatch with its full per-sink outcome, so a
/// diagnostics screen can show the real event stream rather than only what the
/// screen itself triggered.
///
/// Implementations must not throw and must not block; the pipeline calls them
/// synchronously after each dispatch and ignores anything they return.
abstract interface class AnalyticsDeliveryObserver {
  /// Called after an event has been offered to every eligible sink.
  void onEventDelivered(AnalyticsEvent event, AnalyticsDeliveryReport report);

  /// Called after a non-event operation, such as identify or flush.
  ///
  /// [AnalyticsDeliveryReport.operation] names which.
  void onOperationDelivered(AnalyticsDeliveryReport report);
}
