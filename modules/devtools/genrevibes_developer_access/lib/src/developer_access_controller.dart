import 'dart:async';
import 'dart:math' as math;

import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';

import 'developer_access.dart';
import 'developer_access_config.dart';
import 'developer_access_keys.dart';
import 'developer_device_hash.dart';

/// Decides whether this install gets the developer tools and test ads.
///
/// Any one of these grants access:
///
/// * a development build, always;
/// * this device's hash on the hardcoded, env, or remote list;
/// * the passcode, entered in this process.
///
/// The passcode grant is deliberately not persisted. It lasts until the app
/// closes, so a phone left unlocked does not stay unlocked; a phone that should
/// always have access belongs on a list. Wrong attempts are persisted, and
/// [DeveloperAccessConfig.maxPasscodeAttempts] of them lock entry until a
/// development build runs on the device or the app is reinstalled.
///
/// Nothing here logs, stores, or reports the passcode, an attempt, or a device
/// identifier. The identifier is hashed the moment it arrives and discarded.
final class DeveloperAccessController implements StarterModule {
  /// Creates a controller.
  ///
  /// [installMarker] identifies this installation of the app — see
  /// [DeveloperAccessKeys.failuresInstallMarker]. Pass `null` where the
  /// platform removes app storage on uninstall.
  DeveloperAccessController({
    required KeyValueStore store,
    required DeveloperAccessConfig config,
    String? installMarker,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _store = store,
        _config = config,
        _installMarker = installMarker,
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'developer_access',
          state: ModuleState.idle,
          observedAt: clock.now(),
        ),
        _current = DeveloperAccess(
          reason: config.isDevelopmentBuild
              ? DeveloperAccessReason.developmentBuild
              : DeveloperAccessReason.none,
          lockedOut: false,
          attemptsRemaining: config.maxPasscodeAttempts,
        );

  final KeyValueStore _store;
  final DeveloperAccessConfig _config;
  final String? _installMarker;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  final StreamController<DeveloperAccess> _changes =
      StreamController<DeveloperAccess>.broadcast();
  final Set<String> _remoteHashes = <String>{};
  ModuleHealth _health;
  DeveloperAccess _current;
  String? _deviceHash;
  int _failures = 0;
  bool _passcodeGranted = false;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => 'developer_access';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  /// The current decision.
  DeveloperAccess get current => _current;

  /// Emits each changed decision.
  Stream<DeveloperAccess> get changes => _changes.stream;

  bool get _lockedOut => _failures >= _config.maxPasscodeAttempts;

  /// Loads the lockout state. A development build clears it.
  @override
  Future<KitResult<void>> initialize() async {
    if (_disposed) return _notReady();
    if (_initialized) return const KitSuccess<void>(null);
    _initialized = true;
    if (_config.isDevelopmentBuild) {
      await _clearFailures();
    } else {
      _failures = await _readFailures();
    }
    _publish();
    _setHealth(ModuleState.ready);
    return const KitSuccess<void>(null);
  }

  /// Supplies this device's identifier, or `null` when none could be read.
  ///
  /// Hashed immediately; the identifier itself is not kept.
  void setDeviceId(String? deviceId) {
    final trimmed = deviceId?.trim();
    _deviceHash = trimmed == null || trimmed.isEmpty
        ? null
        : DeveloperDeviceHash.of(trimmed);
    _publish();
  }

  /// Replaces the remote list. Malformed entries are ignored.
  void setRemoteDeviceHashes(Iterable<String> hashes) {
    _remoteHashes
      ..clear()
      ..addAll(DeveloperDeviceHash.normalizeAll(hashes));
    _publish();
  }

  /// Checks one passcode attempt.
  ///
  /// A blank attempt is rejected without counting. The attempt that reaches the
  /// limit returns [PasscodeOutcome.lockedOut] rather than
  /// [PasscodeOutcome.incorrect].
  Future<PasscodeOutcome> submitPasscode(String attempt) async {
    if (!_initialized || _disposed || _lockedOut) {
      return PasscodeOutcome.lockedOut;
    }
    if (attempt.trim().isEmpty) return PasscodeOutcome.incorrect;

    if (_config.matchesPasscode(attempt)) {
      _passcodeGranted = true;
      await _clearFailures();
      _publish();
      return PasscodeOutcome.granted;
    }

    _failures++;
    await _store.setInt(DeveloperAccessKeys.failedPasscodeAttempts, _failures);
    final marker = _installMarker;
    if (marker != null) {
      await _store.setString(DeveloperAccessKeys.failuresInstallMarker, marker);
    }
    _publish();
    return _lockedOut ? PasscodeOutcome.lockedOut : PasscodeOutcome.incorrect;
  }

  /// Clears wrong attempts, lifting a lockout.
  Future<KitResult<void>> resetLockout() async {
    if (!_initialized || _disposed) return _notReady();
    await _clearFailures();
    _publish();
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _disposed = true;
    _setHealth(ModuleState.disposed);
    await _changes.close();
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  Future<int> _readFailures() async {
    final count = (await _store.getInt(DeveloperAccessKeys.failedPasscodeAttempts))
        .fold(onSuccess: (value) => value ?? 0, onFailure: (_) => 0);
    if (count <= 0) return 0;
    final marker = _installMarker;
    if (marker == null) return count;
    final recordedOn =
        (await _store.getString(DeveloperAccessKeys.failuresInstallMarker))
            .fold(onSuccess: (value) => value, onFailure: (_) => null);
    if (recordedOn == marker) return count;
    // Counted on a previous installation and restored by a backup.
    await _clearFailures();
    return 0;
  }

  Future<void> _clearFailures() async {
    _failures = 0;
    await _store.remove(DeveloperAccessKeys.failedPasscodeAttempts);
    await _store.remove(DeveloperAccessKeys.failuresInstallMarker);
  }

  void _publish() {
    final hash = _deviceHash;
    final listedIn = <DeveloperDeviceList>{
      if (hash != null && _config.hardcodedDeviceHashes.contains(hash))
        DeveloperDeviceList.hardcoded,
      if (hash != null && _config.environmentDeviceHashes.contains(hash))
        DeveloperDeviceList.environment,
      if (hash != null && _remoteHashes.contains(hash))
        DeveloperDeviceList.remote,
    };
    final reason = _config.isDevelopmentBuild
        ? DeveloperAccessReason.developmentBuild
        : listedIn.isNotEmpty
            ? DeveloperAccessReason.listedDevice
            : _passcodeGranted
                ? DeveloperAccessReason.passcode
                : DeveloperAccessReason.none;
    final next = DeveloperAccess(
      reason: reason,
      deviceHash: hash,
      listedIn: Set<DeveloperDeviceList>.unmodifiable(listedIn),
      lockedOut: _lockedOut,
      attemptsRemaining:
          math.max(0, _config.maxPasscodeAttempts - _failures),
    );
    final previous = _current;
    _current = next;
    if (_same(previous, next)) return;
    if (previous.reason != next.reason) {
      _logger.log(
        KitLogLevel.info,
        'Developer access changed.',
        moduleId: moduleId,
        fields: <String, Object?>{'reason': next.reason.name},
      );
    }
    if (!_changes.isClosed) _changes.add(next);
    if (_initialized && !_disposed) _setHealth(ModuleState.ready);
  }

  static bool _same(DeveloperAccess a, DeveloperAccess b) =>
      a.reason == b.reason &&
      a.deviceHash == b.deviceHash &&
      a.lockedOut == b.lockedOut &&
      a.attemptsRemaining == b.attemptsRemaining &&
      a.listedIn.length == b.listedIn.length &&
      a.listedIn.containsAll(b.listedIn);

  KitFailure<void> _notReady() {
    return const KitFailure<void>(
      KitError(
        code: KitErrorCode.notInitialized,
        message: 'Developer access is not initialized, or has been disposed.',
      ),
    );
  }

  void _setHealth(ModuleState state) {
    _health = ModuleHealth(
      moduleId: moduleId,
      state: state,
      observedAt: _clock.now(),
      details: <String, Object?>{
        'reason': _current.reason.name,
        'lockedOut': _current.lockedOut,
        'deviceResolved': _current.deviceHash != null,
      },
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
