import 'dart:convert';

import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';

import 'remote_config_preferences_client.dart';

/// Cross-launch last-known-good cache backed by SharedPreferences.
final class SharedPreferencesRemoteConfigCache implements RemoteConfigCache {
  /// Creates a namespaced cache.
  SharedPreferencesRemoteConfigCache({
    this.storageKey = 'genrevibes.remote_config.last_known_good.v1',
    RemoteConfigPreferencesClient? client,
  }) : _client = client ?? DefaultRemoteConfigPreferencesClient();

  /// Preferences key. Change it to keep independent app/config namespaces.
  final String storageKey;

  final RemoteConfigPreferencesClient _client;

  @override
  Future<KitResult<RemoteConfigCacheEntry?>> read() async {
    try {
      final encoded = await _client.readString(storageKey);
      if (encoded == null || encoded.isEmpty) {
        return const KitSuccess<RemoteConfigCacheEntry?>(null);
      }
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Cache root must be a JSON object.');
      }
      final rawValues = decoded['values'];
      final storedAtMilliseconds = decoded['storedAtMilliseconds'];
      if (rawValues is! Map<String, Object?> || storedAtMilliseconds is! int) {
        throw const FormatException('Cache fields are missing or invalid.');
      }
      return KitSuccess<RemoteConfigCacheEntry?>(
        RemoteConfigCacheEntry(
          values: rawValues,
          storedAt: DateTime.fromMillisecondsSinceEpoch(
            storedAtMilliseconds,
            isUtc: true,
          ),
        ),
      );
    } on Object catch (error, stackTrace) {
      return KitFailure<RemoteConfigCacheEntry?>(
        KitError(
          code: KitErrorCode.provider,
          message: 'Remote-config cache read failed: $error',
          providerCode: 'shared_preferences_read',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<KitResult<void>> write(RemoteConfigCacheEntry entry) async {
    try {
      final encoded = jsonEncode(<String, Object?>{
        'storedAtMilliseconds': entry.storedAt.toUtc().millisecondsSinceEpoch,
        'values': entry.values,
      });
      await _client.writeString(storageKey, encoded);
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      return KitFailure<void>(
        KitError(
          code: KitErrorCode.provider,
          message: 'Remote-config cache write failed: $error',
          providerCode: 'shared_preferences_write',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
