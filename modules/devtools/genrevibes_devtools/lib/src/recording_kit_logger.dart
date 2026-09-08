import 'dart:async';
import 'dart:collection';

import 'package:genrevibes_core/genrevibes_core.dart';

/// One captured log record.
final class KitLogRecord {
  /// Creates a record.
  const KitLogRecord({
    required this.level,
    required this.message,
    required this.at,
    this.moduleId,
    this.error,
    this.stackTrace,
    this.fields = const <String, Object?>{},
  });

  /// Severity as the module reported it.
  final KitLogLevel level;

  /// What the module said.
  final String message;

  /// When it was recorded.
  final DateTime at;

  /// The module that logged, when it named itself.
  final String? moduleId;

  /// The error the module attached, if any.
  final Object? error;

  /// The stack trace the module attached, if any.
  final StackTrace? stackTrace;

  /// Structured fields the module attached.
  final Map<String, Object?> fields;
}

/// A [KitLogger] that keeps recent records and streams new ones.
///
/// Every module in the kit accepts a `KitLogger` and defaults to
/// [NoopKitLogger], so nothing is observable at runtime. Passing one of these
/// to each module instead turns the whole family into a single readable feed:
/// consent, ads, purchases, remote config and the rest all report through the
/// same channel, in order, with their module id attached.
///
/// This is a development aid. It holds records in memory only, capped at
/// [capacity], and nothing here reaches a network.
final class RecordingKitLogger implements KitLogger {
  /// Creates a logger retaining at most [capacity] records.
  RecordingKitLogger({
    this.capacity = 500,
    KitClock clock = const SystemKitClock(),
    KitLogger? forwardTo,
  })  : _clock = clock,
        _forwardTo = forwardTo;

  /// How many records are retained before the oldest is dropped.
  final int capacity;

  final KitClock _clock;

  /// An optional second logger, so adopting this does not silence an existing
  /// one.
  final KitLogger? _forwardTo;

  final ListQueue<KitLogRecord> _records = ListQueue<KitLogRecord>();
  final StreamController<KitLogRecord> _added =
      StreamController<KitLogRecord>.broadcast();

  /// Records held, newest last.
  List<KitLogRecord> get records => List<KitLogRecord>.unmodifiable(_records);

  /// Emits each record as it arrives.
  Stream<KitLogRecord> get added => _added.stream;

  /// Drops every retained record. Does not affect subscribers.
  void clear() => _records.clear();

  @override
  void log(
    KitLogLevel level,
    String message, {
    String? moduleId,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    _forwardTo?.log(
      level,
      message,
      moduleId: moduleId,
      error: error,
      stackTrace: stackTrace,
      fields: fields,
    );

    final record = KitLogRecord(
      level: level,
      message: message,
      at: _clock.now(),
      moduleId: moduleId,
      error: error,
      stackTrace: stackTrace,
      fields: Map<String, Object?>.unmodifiable(fields),
    );
    _records.addLast(record);
    while (_records.length > capacity) {
      _records.removeFirst();
    }
    if (!_added.isClosed) _added.add(record);
  }

  /// Releases the stream. The logger must not be used afterwards.
  Future<void> dispose() async {
    _records.clear();
    await _added.close();
  }
}
