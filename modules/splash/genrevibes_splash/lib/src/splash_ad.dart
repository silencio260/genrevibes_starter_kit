import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

/// The full-screen ad a splash loads and shows.
final class SplashAdRequest {
  /// Creates a request.
  const SplashAdRequest({
    required this.provider,
    required this.placement,
    this.policy,
    this.canRequest,
  });

  /// Rechecked before loading and showing, for access and remote switches.
  final bool Function()? canRequest;

  /// The provider that serves [placement].
  final AdProvider provider;

  /// A full-screen placement: interstitial, rewarded or app open.
  final AdPlacement placement;

  /// Policy to show through, so suppression and the display lock apply. Null
  /// shows through [provider] directly.
  final AdPolicyController? policy;
}

/// What became of the splash ad.
enum SplashAdStatus {
  /// No ad was asked for.
  notRequested,

  /// The ad was shown and closed.
  shown,

  /// The ad, or the decision about it, did not arrive before the splash
  /// stopped waiting.
  timedOut,

  /// The provider had no ad to show, serves no such format, or refused.
  notReady,

  /// Policy blocked the ad.
  blocked,

  /// Deciding, loading or showing failed.
  failed,

  /// The app was not in the foreground when the ad was due.
  appInBackground,
}

/// How a splash ended.
final class SplashOutcome {
  /// Creates an outcome.
  const SplashOutcome({
    required this.adStatus,
    required this.elapsed,
    this.placement,
    this.reward,
    this.error,
  });

  /// What became of the ad.
  final SplashAdStatus adStatus;

  /// Time from the splash's first frame to its end, including any ad.
  final Duration elapsed;

  /// The placement asked for, when there was one.
  final AdPlacement? placement;

  /// A reward, when a rewarded ad was watched to the end.
  final AdReward? reward;

  /// The failure behind [SplashAdStatus.failed] or [SplashAdStatus.notReady],
  /// when one was reported.
  final KitError? error;

  /// Whether the ad was shown.
  bool get adShown => adStatus == SplashAdStatus.shown;
}

/// Routes launch ads independently from the app's ordinary ad provider.
///
/// Register only integrated providers. The app owns their consent,
/// initialization, premium suppression, event subscriptions and disposal.
/// Unknown providers or unsupported formats never fall back to another ad.
final class SplashAdRegistry {
  /// Creates a registry keyed by stable, remote-configurable provider IDs.
  SplashAdRegistry(Map<String, AdProvider> providers)
      : _providers = Map.unmodifiable(providers);

  final Map<String, AdProvider> _providers;

  /// Selects a provider without initializing it or requesting an ad.
  SplashAdRequest? resolve({
    required String providerId,
    required AdPlacement placement,
    AdPolicyController? policy,
    bool Function()? canRequest,
  }) {
    final provider = _providers[providerId.trim()];
    if (provider == null ||
        !provider.supportedFormats.contains(placement.format)) return null;
    return SplashAdRequest(
      provider: provider,
      placement: placement,
      policy: policy,
      canRequest: canRequest,
    );
  }
}
