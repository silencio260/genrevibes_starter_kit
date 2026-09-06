import 'package:posthog_flutter/posthog_flutter.dart';

/// Application-owned PostHog SDK configuration.
final class GenreVibesPostHogConfiguration {
  /// Creates PostHog configuration.
  const GenreVibesPostHogConfiguration({
    required this.apiKey,
    this.host = 'https://us.i.posthog.com',
    this.debug = false,
    this.captureApplicationLifecycleEvents = true,
    this.sessionReplayEnabled = false,
    this.maskAllTexts = true,
    this.maskAllImages = true,
    this.flushAt = 20,
    this.flushInterval = const Duration(seconds: 30),
  });

  /// PostHog project API key.
  final String apiKey;

  /// PostHog ingestion host.
  final String host;

  /// Whether SDK debug logging is enabled.
  final bool debug;

  /// Whether PostHog records application lifecycle events.
  final bool captureApplicationLifecycleEvents;

  /// Whether mobile session replay is enabled.
  final bool sessionReplayEnabled;

  /// Whether replay masks all rendered text.
  final bool maskAllTexts;

  /// Whether replay masks all rendered images.
  final bool maskAllImages;

  /// Event count that triggers a batch upload.
  final int flushAt;

  /// Maximum time between automatic uploads.
  final Duration flushInterval;

  /// Creates the vendor configuration used by the adapter.
  PostHogConfig toSdkConfiguration() {
    return PostHogConfig(apiKey.trim())
      ..host = host.trim()
      ..debug = debug
      ..captureApplicationLifecycleEvents = captureApplicationLifecycleEvents
      ..sessionReplay = sessionReplayEnabled
      ..sessionReplayConfig.maskAllTexts = maskAllTexts
      ..sessionReplayConfig.maskAllImages = maskAllImages
      ..flushAt = flushAt
      ..flushInterval = flushInterval;
  }
}
