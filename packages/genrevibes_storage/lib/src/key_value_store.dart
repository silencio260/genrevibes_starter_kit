import 'package:genrevibes_core/genrevibes_core.dart';

/// Provider-neutral key-value persistence used by GenRevibes capabilities.
///
/// Implementations must never throw across this boundary. Every failure is
/// reported as a [KitFailure] carrying a normalized [KitError], so a capability
/// package can degrade safely instead of crashing an application.
///
/// A missing key is not a failure. Readers return `KitSuccess(null)` so callers
/// can distinguish "absent" from "storage is broken".
abstract interface class KeyValueStore {
  /// Reads a boolean, or `null` when [key] is absent.
  Future<KitResult<bool?>> getBool(String key);

  /// Reads an integer, or `null` when [key] is absent.
  Future<KitResult<int?>> getInt(String key);

  /// Reads a string, or `null` when [key] is absent.
  Future<KitResult<String?>> getString(String key);

  /// Stores a boolean under [key].
  Future<KitResult<void>> setBool(String key, bool value);

  /// Stores an integer under [key].
  Future<KitResult<void>> setInt(String key, int value);

  /// Stores a string under [key].
  Future<KitResult<void>> setString(String key, String value);

  /// Removes [key]. Removing an absent key succeeds.
  Future<KitResult<void>> remove(String key);
}
