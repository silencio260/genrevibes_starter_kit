import 'dart:async';

import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';

import 'developer_access.dart';
import 'developer_access_controller.dart';
import 'developer_access_keys.dart';

/// Switches that turn ad formats off on a developer's own phone.
///
/// For working on screens without full-screen ads in the way. A switch applies
/// only while [DeveloperAccessController] grants access, so a phone that loses
/// access shows ads normally again, and ordinary users are never affected. The
/// switches are remembered on the device.
///
/// The app asks [allows] wherever it loads or shows a format.
final class DeveloperAdSwitches {
  /// Creates the switches over [store], applied while [access] grants access.
  DeveloperAdSwitches({
    required KeyValueStore store,
    required DeveloperAccessController access,
    KitLogger logger = const NoopKitLogger(),
  })  : _store = store,
        _access = access,
        _logger = logger;

  final KeyValueStore _store;
  final DeveloperAccessController _access;
  final KitLogger _logger;
  final Set<AdFormat> _off = <AdFormat>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  bool _loaded = false;

  StreamSubscription<DeveloperAccess>? _accessChanges;
  bool _lastActive = false;

  /// Emits whenever a switch changes, or developer access is granted or lost,
  /// so an ad view can hide or come back at once.
  Stream<void> get changes {
    _listenToAccess();
    return _changes.stream;
  }

  void _listenToAccess() {
    if (_accessChanges != null) return;
    _lastActive = active;
    _accessChanges = _access.changes.listen((_) {
      if (active == _lastActive) return;
      _lastActive = active;
      if (!_changes.isClosed) _changes.add(null);
    });
  }

  /// Stops following developer access and closes [changes].
  Future<void> dispose() async {
    await _accessChanges?.cancel();
    await _changes.close();
  }

  /// Whether the switches apply right now: developer access is granted.
  bool get active => _access.current.isGranted;

  /// Whether [format] is switched off on this device, applied or not.
  bool isSwitchedOff(AdFormat format) => _off.contains(format);

  /// Whether the app may load and show [format] now.
  bool allows(AdFormat format) => !(active && _off.contains(format));

  /// Reads the remembered switches. Safe to call more than once.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final stored =
        await _store.getStringList(DeveloperAccessKeys.disabledAdFormats);
    final names =
        stored.fold(onSuccess: (value) => value, onFailure: (_) => null);
    if (names == null) return;
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
}
