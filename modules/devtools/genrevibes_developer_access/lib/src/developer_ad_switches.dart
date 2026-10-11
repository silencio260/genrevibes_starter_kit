import 'dart:async';

import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';

import 'developer_access.dart';
import 'developer_access_controller.dart';
import 'developer_access_keys.dart';

/// A developer's own ad controls on their phone: formats turned off, and live
/// instead of test inventory.
///
/// Formats: for working on screens without ads in the way, one at a time or all
/// at once ([setAllEnabled]). The app asks [allows] wherever it loads or shows a
/// format.
///
/// Inventory: developer access normally means test ads. [setLiveInventory]
/// asks for real ads on this phone, to check live fill, without a rebuild. Pass
/// [servesTestAds] to the ad provider when it starts and again on [changes]; an
/// SDK that fixes its mode at start (Appodeal) applies it on the next launch.
///
/// Everything applies only while [DeveloperAccessController] grants access, so a
/// phone that loses access behaves like any other, and ordinary users are never
/// affected. Remembered on the device.
final class DeveloperAdSwitches {
  /// Creates the switches over [store], applied while [access] grants access.
  ///
  /// [liveInventoryForced]: this run asked for live inventory regardless of the
  /// switch (for example a development build started with a live-ads flag).
  /// The switch then reads as on and can't turn it off.
  DeveloperAdSwitches({
    required KeyValueStore store,
    required DeveloperAccessController access,
    KitLogger logger = const NoopKitLogger(),
    this.liveInventoryForced = false,
  })  : _store = store,
        _access = access,
        _logger = logger;

  /// Live inventory is on for this run whatever the switch says.
  final bool liveInventoryForced;

  final KeyValueStore _store;
  final DeveloperAccessController _access;
  final KitLogger _logger;
  final Set<AdFormat> _off = <AdFormat>{};
  bool _liveInventory = false;
  bool? _testAdsAtLaunch;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  bool _loaded = false;
  bool _disposed = false;

  StreamSubscription<DeveloperAccess>? _accessChanges;
  bool _lastActive = false;

  /// Emits whenever a switch changes, or developer access is granted or lost,
  /// so an ad view can hide or come back at once.
  Stream<void> get changes {
    _listenToAccess();
    return _changes.stream;
  }

  void _listenToAccess() {
    if (_disposed || _accessChanges != null) return;
    _lastActive = active;
    _accessChanges = _access.changes.listen((_) {
      if (active == _lastActive) return;
      _lastActive = active;
      if (!_changes.isClosed) _changes.add(null);
    });
  }

  /// Stops following developer access and closes [changes].
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _accessChanges?.cancel();
    await _changes.close();
  }

  /// Whether the switches apply right now: developer access is granted.
  bool get active => _access.current.isGranted;

  /// Whether [format] is switched off on this device, applied or not.
  bool isSwitchedOff(AdFormat format) => _off.contains(format);

  /// Whether the app may load and show [format] now.
  bool allows(AdFormat format) => !(active && _off.contains(format));

  /// Whether every format is switched off on this device, applied or not.
  bool get allSwitchedOff => AdFormat.values.every(_off.contains);

  /// Whether the developer's own switch asks for live inventory, remembered.
  bool get liveInventoryRequested => _liveInventory;

  /// Whether this phone gets real ads: no developer access, or live inventory
  /// forced for this run, or asked for with the switch. What a "Real ads"
  /// switch should show.
  bool get liveInventory => !servesTestAds;

  /// Whether the ad SDK should serve test inventory: developer access, unless
  /// live inventory is forced for this run or asked for on this device.
  bool get servesTestAds =>
      _access.current.servesTestAds &&
      !(liveInventoryForced || _liveInventory);

  /// Whether the ad SDK started with test inventory on this launch (null before
  /// [load]). An SDK that fixes its mode at start keeps it until a restart.
  bool? get servedTestAdsAtLaunch => _testAdsAtLaunch;

  /// Whether the inventory now asked for differs from the launch's: the app
  /// needs a full restart for it to take effect.
  bool get restartRequired =>
      _testAdsAtLaunch != null && _testAdsAtLaunch != servesTestAds;

  /// Reads the remembered switches. Safe to call more than once.
  Future<void> load() async {
    if (_disposed || _loaded) return;
    _loaded = true;
    final live = await _store.getBool(DeveloperAccessKeys.liveAdInventory);
    _liveInventory =
        live.fold(onSuccess: (value) => value ?? false, onFailure: (_) => false);
    // The provider is started from this value right after loading.
    _testAdsAtLaunch = servesTestAds;
    final stored =
        await _store.getStringList(DeveloperAccessKeys.disabledAdFormats);
    final names =
        stored.fold(onSuccess: (value) => value, onFailure: (_) => null);
    if (_disposed || names == null) return;
    final byName = AdFormat.values.asNameMap();
    _off
      ..clear()
      ..addAll(<AdFormat>[
        for (final name in names)
          if (byName[name] case final format?) format,
      ]);
  }

  /// Turns [format] on or off on this device and remembers it.
  Future<KitResult<void>> setEnabled(AdFormat format, bool enabled) async {
    if (_disposed) {
      return const KitFailure<void>(KitError(
          code: KitErrorCode.notInitialized,
          message: 'Developer ad switches were stopped.'));
    }
    final changed = enabled ? _off.remove(format) : _off.add(format);
    if (!changed) return const KitSuccess<void>(null);
    if (!_changes.isClosed) _changes.add(null);
    _logger.log(
      KitLogLevel.info,
      'Developer ad switch changed.',
      moduleId: 'developer_access',
      fields: <String, Object?>{'format': format.name, 'enabled': enabled},
    );
    return _store.setStringList(
      DeveloperAccessKeys.disabledAdFormats,
      <String>[for (final off in _off) off.name],
    );
  }

  /// Turns every format on or off on this device at once and remembers it.
  Future<KitResult<void>> setAllEnabled(bool enabled) async {
    if (_disposed) return _stopped;
    final before = Set<AdFormat>.of(_off);
    if (enabled) {
      _off.clear();
    } else {
      _off.addAll(AdFormat.values);
    }
    if (_off.length == before.length && _off.containsAll(before)) {
      return const KitSuccess<void>(null);
    }
    if (!_changes.isClosed) _changes.add(null);
    _logger.log(
      KitLogLevel.info,
      'Developer ad switches changed for every format.',
      moduleId: 'developer_access',
      fields: <String, Object?>{'enabled': enabled},
    );
    return _store.setStringList(
      DeveloperAccessKeys.disabledAdFormats,
      <String>[for (final off in _off) off.name],
    );
  }

  /// Asks for live (or test) ad inventory on this device and remembers it.
  Future<KitResult<void>> setLiveInventory(bool live) async {
    if (_disposed) return _stopped;
    if (live == _liveInventory) return const KitSuccess<void>(null);
    _liveInventory = live;
    if (!_changes.isClosed) _changes.add(null);
    _logger.log(
      KitLogLevel.info,
      'Developer ad inventory changed.',
      moduleId: 'developer_access',
      fields: <String, Object?>{'live': live},
    );
    return _store.setBool(DeveloperAccessKeys.liveAdInventory, live);
  }

  static const KitFailure<void> _stopped = KitFailure<void>(KitError(
      code: KitErrorCode.notInitialized,
      message: 'Developer ad switches were stopped.'));
}
