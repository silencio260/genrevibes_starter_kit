import 'dart:async';
import 'dart:collection';

import 'package:genrevibes_analytics/genrevibes_analytics.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

/// One delivered event and where it actually went.
final class DeliveredEvent {
  /// Creates a record.
  const DeliveredEvent({
    required this.event,
    required this.report,
    required this.at,
  });

  /// What was sent, after remote name resolution.
  final AnalyticsEvent event;

  /// Which sinks took it, which refused, and whether consent suppressed it.
  final AnalyticsDeliveryReport report;

  /// When it was dispatched.
  final DateTime at;

  /// Whether every attempted sink accepted it.
  bool get isCompleteSuccess => report.isCompleteSuccess;
}

/// Keeps a live record of every analytics event the application emits.
///
/// Firebase's DebugView cannot be switched on from application code: on Android
/// it reads a system property that only a shell can set, and the Analytics API
/// exposes no toggle. So an application that wants to watch its own events
/// during development has to keep that record itself.
///
/// This does, and it sees more than DebugView would: every event from anywhere
/// in the application, with the per-sink outcome attached, including the ones
/// a sink refused and the ones suppressed before any sink saw them.
///
/// Development only. Records are held in memory, capped at [capacity], and
/// nothing here reaches a network. Applications construct it behind their own
/// development flag so release builds carry no history at all.
final class RecordingDeliveryObserver implements AnalyticsDeliveryObserver {
  /// Creates an observer retaining at most [capacity] events.
  RecordingDeliveryObserver({
    this.capacity = 500,
    KitClock clock = const SystemKitClock(),
  }) : _clock = clock;

  /// How many events are retained before the oldest is dropped.
  final int capacity;

  final KitClock _clock;
  final ListQueue<DeliveredEvent> _events = ListQueue<DeliveredEvent>();
  final StreamController<DeliveredEvent> _added =
      StreamController<DeliveredEvent>.broadcast();

  /// Events recorded, oldest first.
  List<DeliveredEvent> get events => List<DeliveredEvent>.unmodifiable(_events);

  /// Emits each event as it is delivered.
  Stream<DeliveredEvent> get added => _added.stream;

  /// Drops the retained history.
  void clear() => _events.clear();

  @override
  void onEventDelivered(AnalyticsEvent event, AnalyticsDeliveryReport report) {
    final record = DeliveredEvent(
      event: event,
      report: report,
      at: _clock.now(),
    );
    _events.addLast(record);
    while (_events.length > capacity) {
      _events.removeFirst();
    }
    if (!_added.isClosed) _added.add(record);
  }

  @override
  void onOperationDelivered(AnalyticsDeliveryReport report) {
    // Identify, flush and consent changes are not events; the log shows what
    // the application emitted, not the pipeline's own housekeeping.
  }

  /// Releases the stream. The observer must not be used afterwards.
  Future<void> dispose() async {
    _events.clear();
    await _added.close();
  }
}
