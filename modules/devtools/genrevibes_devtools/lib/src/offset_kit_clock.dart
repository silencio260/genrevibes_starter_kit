import 'package:genrevibes_core/genrevibes_core.dart';

/// A clock the bench can move forward.
///
/// Most of what the kit decides is time-based and deliberately slow: a rating
/// prompt waits days after install, ad frequency caps wait minutes, retention
/// milestones land on day 1, 3, 7 and 30. None of that can be exercised by
/// tapping a button.
///
/// Every time-dependent module accepts a [KitClock] — `AdPolicyController`,
/// `RatingCoordinator`, `RetentionTracker`, `PermissionRequestThrottle`,
/// `PersistentLocalNotificationScheduler` — so handing them this one turns
/// "wait three days" into a slider.
///
/// The offset applies only to modules constructed with this instance. It does
/// not change the device clock, and anything already persisted keeps its real
/// timestamps, so moving forward and back is non-destructive.
final class OffsetKitClock implements KitClock {
  /// Creates a clock over [delegate], offset by [offset].
  OffsetKitClock({
    KitClock delegate = const SystemKitClock(),
    Duration offset = Duration.zero,
  })  : _delegate = delegate,
        _offset = offset;

  final KitClock _delegate;
  Duration _offset;

  /// How far ahead of the real clock this one reads.
  Duration get offset => _offset;

  /// Sets the offset. Negative values read into the past.
  set offset(Duration value) => _offset = value;

  /// Moves the clock forward by [amount].
  void advance(Duration amount) => _offset += amount;

  /// Returns to real time.
  void reset() => _offset = Duration.zero;

  /// Whether this clock currently disagrees with the device.
  bool get isShifted => _offset != Duration.zero;

  @override
  DateTime now() => _delegate.now().add(_offset);
}
