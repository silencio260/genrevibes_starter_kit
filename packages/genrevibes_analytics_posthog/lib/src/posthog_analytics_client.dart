import 'package:posthog_flutter/posthog_flutter.dart';

/// Injectable boundary around the PostHog Flutter plugin.
abstract interface class PostHogAnalyticsClient {
  /// Configures the PostHog SDK.
  Future<void> setup(PostHogConfig configuration);

  /// Enables event collection.
  Future<void> enable();

  /// Disables event collection.
  Future<void> disable();

  /// Captures an event.
  Future<void> capture(String name, Map<String, Object>? properties);

  /// Identifies a user and optionally sets profile properties.
  Future<void> identify(String userId, Map<String, Object>? properties);

  /// Clears the current identity.
  Future<void> reset();

  /// Flushes queued events.
  Future<void> flush();

  /// Releases PostHog resources.
  Future<void> close();
}

/// Production client backed by the PostHog singleton.
final class DefaultPostHogAnalyticsClient implements PostHogAnalyticsClient {
  /// Creates a production PostHog client.
  DefaultPostHogAnalyticsClient({Posthog? posthog})
      : _posthog = posthog ?? Posthog();

  final Posthog _posthog;

  @override
  Future<void> capture(String name, Map<String, Object>? properties) {
    return _posthog.capture(eventName: name, properties: properties);
  }

  @override
  Future<void> close() => _posthog.close();

  @override
  Future<void> disable() => _posthog.disable();

  @override
  Future<void> enable() => _posthog.enable();

  @override
  Future<void> flush() => _posthog.flush();

  @override
  Future<void> identify(String userId, Map<String, Object>? properties) {
    return _posthog.identify(userId: userId, userProperties: properties);
  }

  @override
  Future<void> reset() => _posthog.reset();

  @override
  Future<void> setup(PostHogConfig configuration) {
    return _posthog.setup(configuration);
  }
}
