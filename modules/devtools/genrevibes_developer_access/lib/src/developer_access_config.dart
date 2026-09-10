import 'dart:convert';

import 'developer_device_hash.dart';

/// Values every portfolio app shares unless it has a reason not to.
abstract final class DeveloperAccessDefaults {
  /// The passcode when a build supplies none.
  static const String passcode = '1234567';

  /// Wrong passcode attempts before entry locks.
  static const int maxPasscodeAttempts = 3;

  /// Taps on the hidden target that open the passcode prompt.
  static const int unlockTaps = 7;
}

/// Build-time inputs to developer access.
///
/// The remote list is not here: it arrives after startup and changes while the
/// app runs, so it is pushed into the controller by a binder instead.
final class DeveloperAccessConfig {
  /// Creates a config.
  ///
  /// [environmentDeviceHashes] is the raw comma-separated env value.
  /// A blank [passcode] means [DeveloperAccessDefaults.passcode].
  DeveloperAccessConfig({
    required this.isDevelopmentBuild,
    Iterable<String> hardcodedDeviceHashes = const <String>[],
    String environmentDeviceHashes = '',
    String passcode = '',
    this.maxPasscodeAttempts = DeveloperAccessDefaults.maxPasscodeAttempts,
  })  : hardcodedDeviceHashes =
            Set<String>.unmodifiable(
              DeveloperDeviceHash.normalizeAll(hardcodedDeviceHashes),
            ),
        environmentDeviceHashes = Set<String>.unmodifiable(
          DeveloperDeviceHash.parseList(environmentDeviceHashes),
        ),
        _passcode = passcode.trim().isEmpty
            ? DeveloperAccessDefaults.passcode
            : passcode.trim() {
    if (maxPasscodeAttempts < 1) {
      throw ArgumentError.value(
        maxPasscodeAttempts,
        'maxPasscodeAttempts',
        'Must be at least 1.',
      );
    }
  }

  /// Whether this is a development build. Grants access, and clears a lockout.
  final bool isDevelopmentBuild;

  /// Hashes compiled into the application.
  final Set<String> hardcodedDeviceHashes;

  /// Hashes from the env file.
  final Set<String> environmentDeviceHashes;

  /// Wrong attempts allowed before entry locks.
  final int maxPasscodeAttempts;

  /// Deliberately private and absent from [toString]: nothing should be able to
  /// print it, log it, or put it in a crash report by accident.
  final String _passcode;

  /// Whether [attempt] is the passcode.
  ///
  /// Compares every byte regardless of where the first difference is.
  bool matchesPasscode(String attempt) {
    final expected = utf8.encode(_passcode);
    final actual = utf8.encode(attempt.trim());
    var difference = expected.length ^ actual.length;
    for (var i = 0; i < expected.length; i++) {
      difference |= expected[i] ^ (i < actual.length ? actual[i] : 0);
    }
    return difference == 0;
  }

  @override
  String toString() => 'DeveloperAccessConfig('
      'developmentBuild: $isDevelopmentBuild, '
      'hardcoded: ${hardcodedDeviceHashes.length}, '
      'environment: ${environmentDeviceHashes.length})';
}
