import 'package:flutter/foundation.dart';

/// Logging verbosity requested from the RevenueCat SDK.
enum RevenueCatLogging {
  /// Log only errors.
  errors,

  /// Log warnings and errors.
  warnings,

  /// Log normal operational information.
  info,

  /// Log debug information. Intended for non-production builds.
  debug,
}

/// Platform-specific configuration for [RevenueCatIapProvider].
final class RevenueCatConfiguration {
  /// Creates RevenueCat configuration.
  const RevenueCatConfiguration({
    this.androidApiKey,
    this.iosApiKey,
    this.macosApiKey,
    this.webApiKey,
    this.initialAppUserId,
    this.logging = RevenueCatLogging.errors,
  });

  /// Public RevenueCat Android SDK key.
  final String? androidApiKey;

  /// Public RevenueCat iOS SDK key.
  final String? iosApiKey;

  /// Public RevenueCat macOS SDK key.
  final String? macosApiKey;

  /// Public RevenueCat web SDK key.
  final String? webApiKey;

  /// Stable application user ID used during initial configuration.
  final String? initialAppUserId;

  /// Requested SDK logging verbosity.
  final RevenueCatLogging logging;

  /// Returns the API key for the current Flutter target.
  String? apiKeyForCurrentPlatform() {
    if (kIsWeb) return _nonEmpty(webApiKey);

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _nonEmpty(androidApiKey),
      TargetPlatform.iOS => _nonEmpty(iosApiKey),
      TargetPlatform.macOS => _nonEmpty(macosApiKey ?? iosApiKey),
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.windows =>
        null,
    };
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
