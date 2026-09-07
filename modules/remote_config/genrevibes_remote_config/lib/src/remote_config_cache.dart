import 'package:genrevibes_core/genrevibes_core.dart';

/// Serializable last-known-good remote values.
final class RemoteConfigCacheEntry {
  /// Creates a cache entry.
  RemoteConfigCacheEntry({
    required Map<String, Object?> values,
    required this.storedAt,
  }) : values = Map<String, Object?>.unmodifiable(values);

  /// Previously validated values.
  final Map<String, Object?> values;

  /// Time these values were persisted.
  final DateTime storedAt;
}

/// Persistence boundary supplied by an application or storage adapter.
abstract interface class RemoteConfigCache {
  /// Loads the previous last-known-good entry.
  Future<KitResult<RemoteConfigCacheEntry?>> read();

  /// Persists [entry] atomically when possible.
  Future<KitResult<void>> write(RemoteConfigCacheEntry entry);
}

/// Process-local cache useful for tests and apps that only need session safety.
final class MemoryRemoteConfigCache implements RemoteConfigCache {
  RemoteConfigCacheEntry? _entry;

  @override
  Future<KitResult<RemoteConfigCacheEntry?>> read() async {
    return KitSuccess<RemoteConfigCacheEntry?>(_entry);
  }

  @override
  Future<KitResult<void>> write(RemoteConfigCacheEntry entry) async {
    _entry = entry;
    return const KitSuccess<void>(null);
  }
}
