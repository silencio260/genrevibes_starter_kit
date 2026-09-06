import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';

/// Remote-overridable analytics event names.
///
/// Every canonical event name the portfolio emits gets a remote-config key
/// named `event_<field>` whose default is the canonical literal. Overriding a
/// value renames that event in every sink without a release; leaving it blank
/// keeps the canonical name.
abstract final class AnalyticsNamesSchema {
  static const _codec = RemoteConfigStringCodec();

  /// Canonical literal → remote key, in the portfolio's historical order.
  static const Map<String, String> _remoteKeyByCanonical = <String, String>{
    'ad_impression': 'event_ad_impression',
    'custom_purchase': 'event_custom_purchase',
    'custom_paywall_cancelled': 'event_paywall_cancelled',
    'custom_purchases_restored': 'event_purchases_restored',
    'retention_app_opened': 'event_app_opened',
    'retention_session_started': 'event_session_started',
    'retention_day_1_returned': 'event_day1_returned',
    'retention_day_3_returned': 'event_day3_returned',
    'retention_day_7_returned': 'event_day7_returned',
    'retention_day_30_returned': 'event_day30_returned',
    'user_segment_update': 'event_segment_update',
    'user_is_loyal': 'event_user_is_loyal',
    'user_is_power_user': 'event_user_is_power_user',
    'offer_shown': 'event_offer_shown',
    'app_open': 'event_app_open',
    'onboarding_complete': 'event_onboarding_complete',
    'start_trial': 'event_start_trial',
    'subscribe': 'event_subscribe',
    'purchase': 'event_purchase',
    'refund': 'event_refund',
    'iap_error': 'event_iap_error',
    'view_paywall': 'event_view_paywall',
    'view_paywall_modal': 'event_view_paywall_modal',
    'goto_app_store_page': 'event_goto_app_store',
    'goto_home_page': 'event_goto_home',
    'show_help': 'event_show_help',
    'share_app': 'event_share_app',
    'rate_app': 'event_rate_app',
    'feedback_submit': 'event_feedback_submit',
    'save_status': 'event_save_status',
    'download_all': 'event_download_all',
    'remove_ads_clicked': 'event_remove_ads_clicked',
    'auto_save_enabled': 'event_auto_save_enabled',
    'auto_save_disabled': 'event_auto_save_disabled',
    'ad_show': 'event_ad_show',
    'ad_click': 'event_ad_click',
    'ad_error': 'event_ad_error',
    'request_notification_permission': 'event_request_notification',
    'grant_notification_permission': 'event_grant_notification',
    'request_storage_permission': 'event_request_storage',
    'grant_storage_permission': 'event_grant_storage',
    'denied_storage_permission': 'event_denied_storage',
    'app_error_operation_failed': 'event_app_error',
    'rating_maybe_later': 'event_rating_maybe_later',
    'rating_never': 'event_rating_never',
    'rating_submitted': 'event_rating_submitted',
    'rating_4_stars': 'event_rating4_stars',
    'rating_5_stars': 'event_rating5_stars',
  };

  /// Every canonical event name.
  static Iterable<String> get canonicalNames => _remoteKeyByCanonical.keys;

  /// The remote key holding the override for [canonicalName], if any.
  static String? remoteKeyFor(String canonicalName) =>
      _remoteKeyByCanonical[canonicalName];

  /// The typed key for [canonicalName], if the name is known.
  static RemoteConfigKey<String>? keyFor(String canonicalName) {
    final remote = _remoteKeyByCanonical[canonicalName];
    if (remote == null) return null;
    return RemoteConfigKey<String>(
      name: remote,
      defaultValue: canonicalName,
      codec: _codec,
    );
  }

  /// Every key, widened for a schema.
  static List<RemoteConfigKey<Object?>> get all => <RemoteConfigKey<Object?>>[
        for (final canonical in canonicalNames)
          remoteConfigKey(keyFor(canonical)!),
      ];
}
