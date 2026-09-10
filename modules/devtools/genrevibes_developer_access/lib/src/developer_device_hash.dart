import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The one-way form a developer device is listed under.
///
/// Every list that names a developer device ships to people who are not the
/// developer: a hardcoded list and an env value are compiled into the binary,
/// and a remote-config value is downloaded by every install. A raw device
/// identifier in any of them is published. The hash is what goes in the lists
/// instead — the device hashes its own identifier and compares.
///
/// The identifiers hashed here are random UUIDs (Android's app set ID, iOS's
/// identifierForVendor), so the hash cannot be reversed or guessed, and knowing
/// a listed hash does not let another device produce it.
///
/// The salt is shared by the whole portfolio on purpose. Android's
/// developer-scoped app set ID and iOS's identifierForVendor are the same for
/// every app from one developer on a device, so one hash covers a phone in
/// every app, and one list can be pasted into every project.
abstract final class DeveloperDeviceHash {
  /// Portfolio-wide salt. Changing it invalidates every list in every app.
  static const String salt = 'genrevibes.developer_device.v1';

  static final RegExp _shape = RegExp(r'^[0-9a-f]{64}$');

  /// The hash for [deviceId].
  ///
  /// Case and surrounding whitespace are ignored, so the same UUID reported in
  /// upper case by one platform API and lower case by another hashes the same.
  static String of(String deviceId) {
    final normalized = deviceId.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw ArgumentError.value(deviceId, 'deviceId', 'Must not be blank.');
    }
    return sha256.convert(utf8.encode('$salt:$normalized')).toString();
  }

  /// [value] as a canonical hash, or `null` when it is not one.
  static String? tryNormalize(String value) {
    final normalized = value.trim().toLowerCase();
    return _shape.hasMatch(normalized) ? normalized : null;
  }

  /// Every well-formed hash in [values]. Anything else is dropped, so one bad
  /// entry cannot void the rest of a list.
  static Set<String> normalizeAll(Iterable<String> values) => <String>{
        for (final value in values)
          if (tryNormalize(value) case final hash?) hash,
      };

  /// Parses a comma-separated list, the shape an env value takes.
  static Set<String> parseList(String commaSeparated) =>
      normalizeAll(commaSeparated.split(','));
}
