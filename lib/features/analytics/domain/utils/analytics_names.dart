import '../../../services/remote_config/domain/repositories/remote_config_repository.dart';

/// Centralized class for analytics event names.
///
/// Names can be overridden via Firebase Remote Config.
class AnalyticsNames {
  static final AnalyticsNames _instance = AnalyticsNames._internal();
  factory AnalyticsNames() => _instance;
  AnalyticsNames._internal();

  static AnalyticsNames get instance => _instance;

  // Revenue Events
  String adImpression = 'ad_impression';
  String customPurchase = 'custom_purchase';
  String paywallCancelled = 'custom_paywall_cancelled';
  String purchasesRestored = 'custom_purchases_restored';

  // Retention
  String appOpened = 'retention_app_opened';
  String sessionStarted = 'retention_session_started';
  String day1Returned = 'retention_day_1_returned';
  String day3Returned = 'retention_day_3_returned';
  String day7Returned = 'retention_day_7_returned';
  String day30Returned = 'retention_day_30_returned';

  // Targeting
  String segmentUpdate = 'user_segment_update';
  String userIsLoyal = 'user_is_loyal';
  String userIsPowerUser = 'user_is_power_user';
  String offerShown = 'offer_shown';

  // App Lifecycle
  String appOpen = 'app_open';
  String onboardingComplete = 'onboarding_complete';
  String startTrial = 'start_trial';
  String subscribe = 'subscribe';
  String purchase = 'purchase';
  String refund = 'refund';
  String iapError = 'iap_error';

  // Navigation / UI
  String viewPaywall = 'view_paywall';
  String viewPaywallModal = 'view_paywall_modal';
  String gotoAppStore = 'goto_app_store_page';
  String gotoHome = 'goto_home_page';
  String showHelp = 'show_help';
  String shareApp = 'share_app';
  String rateApp = 'rate_app';
  String feedbackSubmit = 'feedback_submit';

  // Features
  String saveStatus = 'save_status';
  String downloadAll = 'download_all';
  String removeAdsClicked = 'remove_ads_clicked';
  String autoSaveEnabled = 'auto_save_enabled';
  String autoSaveDisabled = 'auto_save_disabled';

  // Ads Interaction
  String adShow = 'ad_show';
  String adClick = 'ad_click';
  String adError = 'ad_error';

  // Permissions
  String requestNotification = 'request_notification_permission';
  String grantNotification = 'grant_notification_permission';
  String requestStorage = 'request_storage_permission';
  String grantStorage = 'grant_storage_permission';
  String deniedStorage = 'denied_storage_permission';

  // Quality / Errors
  String appError = 'app_error_operation_failed';

  // Rating
  String ratingMaybeLater = 'rating_maybe_later';
  String ratingNever = 'rating_never';
  String ratingSubmitted = 'rating_submitted';
  String rating4Stars = 'rating_4_stars';
  String rating5Stars = 'rating_5_stars';

  /// Initialize names from Remote Config
  void initialize(RemoteConfigRepository remoteConfig) {
    adImpression = _get(remoteConfig, 'event_ad_impression', adImpression);
    customPurchase = _get(
      remoteConfig,
      'event_custom_purchase',
      customPurchase,
    );
    paywallCancelled = _get(
      remoteConfig,
      'event_paywall_cancelled',
      paywallCancelled,
    );
    purchasesRestored = _get(
      remoteConfig,
      'event_purchases_restored',
      purchasesRestored,
    );
    appOpen = _get(remoteConfig, 'event_app_open', appOpen);
    onboardingComplete = _get(
      remoteConfig,
      'event_onboarding_complete',
      onboardingComplete,
    );
    viewPaywall = _get(remoteConfig, 'event_view_paywall', viewPaywall);
    viewPaywallModal = _get(
      remoteConfig,
      'event_view_paywall_modal',
      viewPaywallModal,
    );
    gotoAppStore = _get(remoteConfig, 'event_goto_app_store', gotoAppStore);
    gotoHome = _get(remoteConfig, 'event_goto_home', gotoHome);
    showHelp = _get(remoteConfig, 'event_show_help', showHelp);
    shareApp = _get(remoteConfig, 'event_share_app', shareApp);
    saveStatus = _get(remoteConfig, 'event_save_status', saveStatus);
    downloadAll = _get(remoteConfig, 'event_download_all', downloadAll);
    removeAdsClicked = _get(
      remoteConfig,
      'event_remove_ads_clicked',
      removeAdsClicked,
    );
    autoSaveEnabled = _get(
      remoteConfig,
      'event_auto_save_enabled',
      autoSaveEnabled,
    );
    autoSaveDisabled = _get(
      remoteConfig,
      'event_auto_save_disabled',
      autoSaveDisabled,
    );
    requestNotification = _get(
      remoteConfig,
      'event_request_notification',
      requestNotification,
    );
    grantNotification = _get(
      remoteConfig,
      'event_grant_notification',
      grantNotification,
    );
    requestStorage = _get(
      remoteConfig,
      'event_request_storage',
      requestStorage,
    );
    grantStorage = _get(remoteConfig, 'event_grant_storage', grantStorage);
    deniedStorage = _get(remoteConfig, 'event_denied_storage', deniedStorage);
    appError = _get(remoteConfig, 'event_app_error', appError);
    ratingMaybeLater = _get(
      remoteConfig,
      'event_rating_maybe_later',
      ratingMaybeLater,
    );
    ratingNever = _get(remoteConfig, 'event_rating_never', ratingNever);
    ratingSubmitted = _get(
      remoteConfig,
      'event_rating_submitted',
      ratingSubmitted,
    );
    rating4Stars = _get(remoteConfig, 'event_rating_4_stars', rating4Stars);
    rating5Stars = _get(remoteConfig, 'event_rating_5_stars', rating5Stars);

    // Retention
    appOpened = _get(remoteConfig, 'event_app_opened', appOpened);
    sessionStarted = _get(
      remoteConfig,
      'event_session_started',
      sessionStarted,
    );
    day1Returned = _get(remoteConfig, 'event_day_1_returned', day1Returned);
    day3Returned = _get(remoteConfig, 'event_day_3_returned', day3Returned);
    day7Returned = _get(remoteConfig, 'event_day_7_returned', day7Returned);
    day30Returned = _get(remoteConfig, 'event_day_30_returned', day30Returned);

    // Targeting
    segmentUpdate = _get(remoteConfig, 'event_segment_update', segmentUpdate);
    userIsLoyal = _get(remoteConfig, 'event_user_is_loyal', userIsLoyal);
    userIsPowerUser = _get(
      remoteConfig,
      'event_user_is_power_user',
      userIsPowerUser,
    );
    offerShown = _get(remoteConfig, 'event_offer_shown', offerShown);
  }

  String _get(RemoteConfigRepository rc, String key, String defaultValue) {
    final value = rc.getString(key);
    return value.isNotEmpty ? value : defaultValue;
  }
}
