import 'package:genrevibes_analytics/genrevibes_analytics.dart';
import 'package:mixpanel_flutter_session_replay/mixpanel_flutter_session_replay.dart';

/// Privacy-first configuration for Mixpanel session replay.
final class GenRevibesMixpanelReplayConfiguration {
  /// Creates session-replay configuration.
  const GenRevibesMixpanelReplayConfiguration({
    required this.token,
    required this.distinctId,
    this.maskAllText = true,
    this.maskAllImages = true,
    this.sessionsPercent = 0,
    this.wifiOnly = false,
    this.flushInterval = const Duration(seconds: 10),
    this.storageQuotaMb = 50,
    this.remoteSettingsMode = RemoteSettingsMode.disabled,
  });

  /// Mixpanel project token.
  final String token;

  /// Stable anonymous or authenticated ID used for replay correlation.
  final String distinctId;

  /// Whether all rendered text is masked automatically.
  final bool maskAllText;

  /// Whether all rendered images are masked automatically.
  final bool maskAllImages;

  /// Percentage of eligible sessions to record. Defaults to zero so replay
  /// requires an explicit application decision.
  final double sessionsPercent;

  /// Whether uploads are restricted to Wi-Fi on mobile.
  final bool wifiOnly;

  /// Automatic replay upload interval.
  final Duration flushInterval;

  /// Maximum local replay queue size in megabytes.
  final int storageQuotaMb;

  /// Mixpanel remote replay-settings behavior.
  final RemoteSettingsMode remoteSettingsMode;

  /// Returns a copy with [plan]'s masking and SDK self-sampling turned off.
  ///
  /// Use this when a `SessionReplayController` decides recording through
  /// `MixpanelSessionReplayRecorder`. Masking is read once at setup, so the
  /// plan must be resolved before the SDK is configured; `sessionsPercent` is
  /// forced to 0 so the SDK never starts recording outside the rollout.
  GenRevibesMixpanelReplayConfiguration withSessionReplay(
    SessionReplayPlan plan,
  ) {
    return GenRevibesMixpanelReplayConfiguration(
      token: token,
      distinctId: distinctId,
      maskAllText: plan.maskAllText,
      maskAllImages: plan.maskAllImages,
      sessionsPercent: 0,
      wifiOnly: wifiOnly,
      flushInterval: flushInterval,
      storageQuotaMb: storageQuotaMb,
      remoteSettingsMode: remoteSettingsMode,
    );
  }

  /// Converts this application configuration to the vendor options object.
  SessionReplayOptions toSdkOptions() {
    return SessionReplayOptions(
      autoMaskedViews: <AutoMaskedView>{
        if (maskAllText) AutoMaskedView.text,
        if (maskAllImages) AutoMaskedView.image,
      },
      autoRecordSessionsPercent: sessionsPercent,
      flushInterval: flushInterval,
      storageQuotaMB: storageQuotaMb,
      remoteSettingsMode: remoteSettingsMode,
      platformOptions: PlatformOptions(
        mobile: MobileOptions(wifiOnly: wifiOnly),
      ),
    );
  }
}
