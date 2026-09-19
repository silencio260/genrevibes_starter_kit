import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';

import 'analytics_sink.dart';
import 'model/analytics_event.dart';
import 'model/analytics_user.dart';

/// Wraps one [AnalyticsSink] with an on/off switch that is independent of
/// consent, so a single provider can be turned off — to stop paying for its
/// events, say — while every other sink keeps collecting.
///
/// Consent still wins. The provider collects only while the pipeline allows
/// collection *and* this switch is on; switching on never overrides a denied
/// consent.
///
/// A sink that starts switched off is never initialized, so its SDK sends
/// nothing at all — not even the automatic first-open events some providers
/// emit on setup — until it is switched on. Switching off after startup turns
/// provider-side collection off (Mixpanel's `optOutTracking`, for example) and
/// drops every later call before it reaches the provider.
///
/// While switched off the pipeline still lists this sink as delivered: the
/// event was handled as instructed, and a remote kill switch is not a fault.
/// [health] reports [ModuleState.disabled] so diagnostics show the difference.
final class SwitchableAnalyticsSink implements AnalyticsSink {
  /// Wraps [inner]. [enabled] is the starting position, normally the cached
  /// remote value so a switched-off provider stays off from the first frame.
  SwitchableAnalyticsSink(
    AnalyticsSink inner, {
    bool enabled = true,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _inner = inner,
        _enabled = enabled,
        _clock = clock,
        _logger = logger {
    _innerHealth = inner.healthChanges.listen((health) {
      if (_enabled && !_healthChanges.isClosed) _healthChanges.add(health);
    });
  }

  final AnalyticsSink _inner;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  late final StreamSubscription<ModuleHealth> _innerHealth;
  Future<void> _serial = Future<void>.value();
  bool _enabled;
  bool _initializeRequested = false;
  bool _innerInitialized = false;
  bool _collectionRequested = true;
  bool _disposed = false;

  /// The wrapped sink.
  AnalyticsSink get inner => _inner;

  /// Whether this provider is switched on.
  bool get enabled => _enabled;

  @override
  String get sinkId => _inner.sinkId;

  @override
  String get moduleId => _inner.moduleId;

  @override
  ModuleHealth get health => _enabled ? _inner.health : _switchedOffHealth();

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  Future<KitResult<void>> initialize() => _run(() async {
        if (_disposed) return _notReady();
        _initializeRequested = true;
        if (!_enabled) {
          _emitHealth();
          return const KitSuccess<void>(null);
        }
        return _initializeInner();
      });

  /// Switches this provider on or off. Safe to call before initialization.
  ///
  /// Switching on after startup initializes the provider if it was skipped,
  /// then restores whatever collection state the pipeline last asked for.
  Future<KitResult<void>> setEnabled(bool enabled) => _run(() async {
        if (_disposed) return _notReady();
        if (_enabled == enabled) return const KitSuccess<void>(null);
        _enabled = enabled;
        _logger.log(
          KitLogLevel.info,
          enabled ? 'Analytics sink switched on.' : 'Analytics sink switched off.',
          moduleId: moduleId,
        );
        final KitResult<void> result;
        if (!enabled) {
          result = _innerInitialized
              ? await _inner.setCollectionEnabled(false)
              : const KitSuccess<void>(null);
        } else if (!_initializeRequested) {
          // The pipeline has not started this sink yet; initialize() will.
          result = const KitSuccess<void>(null);
        } else {
          final initialized = await _initializeInner();
          result = initialized.isFailure
              ? initialized
              : await _inner.setCollectionEnabled(_collectionRequested);
        }
        _emitHealth();
        return result;
      });

  @override
  Future<KitResult<void>> setCollectionEnabled(bool enabled) => _run(() async {
        _collectionRequested = enabled;
        if (!_innerInitialized) return const KitSuccess<void>(null);
        return _inner.setCollectionEnabled(enabled && _enabled);
      });

  @override
  Future<KitResult<void>> track(AnalyticsEvent event) =>
      _enabled ? _inner.track(event) : _skipped();

  @override
  Future<KitResult<void>> identify(AnalyticsUser user) =>
      _enabled ? _inner.identify(user) : _skipped();

  @override
  Future<KitResult<void>> setUserProperties(Map<String, Object?> properties) =>
      _enabled ? _inner.setUserProperties(properties) : _skipped();

  @override
  Future<KitResult<void>> resetIdentity() =>
      _innerInitialized ? _inner.resetIdentity() : _skipped();

  @override
  Future<KitResult<void>> flush() =>
      _enabled && _innerInitialized ? _inner.flush() : _skipped();

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _disposed = true;
    await _serial;
    await _innerHealth.cancel();
    final result = await _inner.dispose();
    await _healthChanges.close();
    return result;
  }

  Future<KitResult<void>> _initializeInner() async {
    if (_innerInitialized) return const KitSuccess<void>(null);
    final result = await _inner.initialize();
    if (result.isSuccess) _innerInitialized = true;
    return result;
  }

  /// Runs [operation] after every earlier switch/initialize/collection call,
  /// so a remote change arriving mid-startup cannot interleave with setup.
  Future<KitResult<void>> _run(Future<KitResult<void>> Function() operation) {
    final result = _serial.then((_) => operation());
    _serial = result.then((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  void _emitHealth() {
    if (!_healthChanges.isClosed) _healthChanges.add(health);
  }

  ModuleHealth _switchedOffHealth() {
    return ModuleHealth(
      moduleId: moduleId,
      provider: _inner.health.provider,
      state: ModuleState.disabled,
      observedAt: _clock.now(),
      details: const <String, Object?>{'switched_off': true},
    );
  }

  static Future<KitResult<void>> _skipped() =>
      Future<KitResult<void>>.value(const KitSuccess<void>(null));

  static KitFailure<void> _notReady() {
    return const KitFailure<void>(
      KitError(
        code: KitErrorCode.notInitialized,
        message: 'Switchable analytics sink has been disposed.',
      ),
    );
  }
}
