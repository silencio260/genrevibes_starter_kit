import 'package:genrevibes_analytics/genrevibes_analytics.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Application-owned PostHog SDK configuration.
final class GenRevibesPostHogConfiguration {
  /// Creates PostHog configuration.
  const GenRevibesPostHogConfiguration({
    required this.apiKey,
    this.host = 'https://us.i.posthog.com',
    this.debug = false,
    this.captureApplicationLifecycleEvents = true,
    this.sessionReplayEnabled = false,
    this.maskAllTexts = false,
    this.maskAllImages = false,
    this.surveys = false,
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

  /// Whether mobile session replay starts recording at launch.
  ///
  /// This is the launch decision only. Recording can be started and stopped
  /// afterwards through [PostHogSessionReplayRecorder], which is how a rollout
  /// percentage or a developer's override takes effect without a relaunch.
  final bool sessionReplayEnabled;

  /// Whether replay masks all rendered text.
  ///
  /// Off, matching the SessionReplayPolicy default. A masked replay shows grey
  /// boxes moving around and cannot answer what replay is paid for, so masking
  /// is something an application turns on for a reason rather than something it
  /// pays for by default.
  ///
  /// Fixed for the life of the process either way: the SDK builds its mask
  /// parsers when it is configured. Changing this needs a relaunch, which is
  /// why the plan that produced it is resolved before the SDK is set up rather
  /// than after.
  final bool maskAllTexts;

  /// Whether replay masks all rendered images. Same timing as [maskAllTexts].
  final bool maskAllImages;

  /// Whether PostHog may present its own surveys.
  ///
  /// Stated rather than left to the SDK, whose default turned this on in 5.x.
  /// An analytics SDK showing an app's users a dialog nobody in the app asked
  /// for is a product decision, and it belongs to the application.
  final bool surveys;

  /// Event count that triggers a batch upload.
  final int flushAt;

  /// Maximum time between automatic uploads.
  final Duration flushInterval;

  /// Copies this configuration with the given overrides.
  GenRevibesPostHogConfiguration copyWith({
    String? apiKey,
    String? host,
    bool? debug,
    bool? captureApplicationLifecycleEvents,
    bool? sessionReplayEnabled,
    bool? maskAllTexts,
    bool? maskAllImages,
    bool? surveys,
    int? flushAt,
    Duration? flushInterval,
  }) {
    return GenRevibesPostHogConfiguration(
      apiKey: apiKey ?? this.apiKey,
      host: host ?? this.host,
      debug: debug ?? this.debug,
      captureApplicationLifecycleEvents: captureApplicationLifecycleEvents ??
          this.captureApplicationLifecycleEvents,
      sessionReplayEnabled: sessionReplayEnabled ?? this.sessionReplayEnabled,
      maskAllTexts: maskAllTexts ?? this.maskAllTexts,
      maskAllImages: maskAllImages ?? this.maskAllImages,
      surveys: surveys ?? this.surveys,
      flushAt: flushAt ?? this.flushAt,
      flushInterval: flushInterval ?? this.flushInterval,
    );
  }

  /// Copies this configuration with every replay setting [plan] decided.
  ///
  /// The whole point of resolving the plan before the SDK is configured: all
  /// three values here are read once, at setup, and only [recording] can be
  /// changed again while the process lives.
  GenRevibesPostHogConfiguration withSessionReplay(SessionReplayPlan plan) {
    return copyWith(
      sessionReplayEnabled: plan.recording,
      maskAllTexts: plan.maskAllText,
      maskAllImages: plan.maskAllImages,
    );
  }

  /// Creates the vendor configuration used by the adapter.
  PostHogConfig toSdkConfiguration() {
    return PostHogConfig(apiKey.trim())
      ..host = host.trim()
      ..debug = debug
      ..captureApplicationLifecycleEvents = captureApplicationLifecycleEvents
      ..sessionReplay = sessionReplayEnabled
      ..sessionReplayConfig.maskAllTexts = maskAllTexts
      ..sessionReplayConfig.maskAllImages = maskAllImages
      ..surveys = surveys
      ..flushAt = flushAt
      ..flushInterval = flushInterval;
  }
}
