import 'model/local_notification.dart';

/// Supplies desired local campaigns from hardcoded data, remote config, or both.
abstract interface class NotificationCampaignSource {
  /// Returns the complete desired schedule for this source.
  Future<List<LocalNotificationRequest>> loadCampaigns();
}

/// Fixed campaigns bundled with an application.
final class StaticNotificationCampaignSource
    implements NotificationCampaignSource {
  /// Creates a fixed campaign source.
  const StaticNotificationCampaignSource(this.campaigns);

  /// Bundled campaigns.
  final List<LocalNotificationRequest> campaigns;

  @override
  Future<List<LocalNotificationRequest>> loadCampaigns() async =>
      List<LocalNotificationRequest>.unmodifiable(campaigns);
}

/// Tries [primary] and falls back to [fallback] when it fails.
final class FallbackNotificationCampaignSource
    implements NotificationCampaignSource {
  /// Creates a remote-first or otherwise layered campaign source.
  const FallbackNotificationCampaignSource({
    required this.primary,
    required this.fallback,
  });

  /// Preferred source, commonly backed by remote config.
  final NotificationCampaignSource primary;

  /// Safe bundled source.
  final NotificationCampaignSource fallback;

  @override
  Future<List<LocalNotificationRequest>> loadCampaigns() async {
    try {
      return await primary.loadCampaigns();
    } on Object {
      return fallback.loadCampaigns();
    }
  }
}
