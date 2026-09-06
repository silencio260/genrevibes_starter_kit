import 'package:mixpanel_flutter/mixpanel_flutter.dart';

import 'mixpanel_configuration.dart';

/// Injectable boundary around the Mixpanel Flutter plugin.
abstract interface class MixpanelAnalyticsClient {
  /// Initializes the SDK.
  Future<void> setup(GenreVibesMixpanelConfiguration configuration);

  /// Enables or disables analytics collection.
  Future<void> setCollectionEnabled(bool enabled);

  /// Records an event.
  Future<void> track(String name, Map<String, Object>? properties);

  /// Identifies the current user.
  Future<void> identify(String userId);

  /// Updates properties for the current user profile.
  Future<void> setPeopleProperties(Map<String, Object> properties);

  /// Clears the current identity.
  Future<void> reset();

  /// Flushes buffered events.
  Future<void> flush();
}

/// Production client backed by `mixpanel_flutter`.
final class DefaultMixpanelAnalyticsClient implements MixpanelAnalyticsClient {
  Mixpanel? _mixpanel;

  Mixpanel get _readyMixpanel {
    final mixpanel = _mixpanel;
    if (mixpanel == null) {
      throw StateError('Mixpanel has not been initialized.');
    }
    return mixpanel;
  }

  @override
  Future<void> setup(GenreVibesMixpanelConfiguration configuration) async {
    final mixpanel = await Mixpanel.init(
      configuration.token.trim(),
      trackAutomaticEvents: configuration.trackAutomaticEvents,
      optOutTrackingDefault: configuration.optOutTrackingDefault,
    );
    mixpanel.setLoggingEnabled(configuration.loggingEnabled);
    final serverUrl = configuration.serverUrl?.trim();
    if (serverUrl != null && serverUrl.isNotEmpty) {
      mixpanel.setServerURL(serverUrl);
    }
    final flushBatchSize = configuration.flushBatchSize;
    if (flushBatchSize != null) {
      mixpanel.setFlushBatchSize(flushBatchSize);
    }
    _mixpanel = mixpanel;
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    if (enabled) {
      _readyMixpanel.optInTracking();
    } else {
      _readyMixpanel.optOutTracking();
    }
  }

  @override
  Future<void> track(String name, Map<String, Object>? properties) {
    return _readyMixpanel.track(name, properties: properties);
  }

  @override
  Future<void> identify(String userId) => _readyMixpanel.identify(userId);

  @override
  Future<void> setPeopleProperties(Map<String, Object> properties) async {
    final people = _readyMixpanel.getPeople();
    for (final entry in properties.entries) {
      people.set(entry.key, entry.value);
    }
  }

  @override
  Future<void> reset() => _readyMixpanel.reset();

  @override
  Future<void> flush() => _readyMixpanel.flush();
}
