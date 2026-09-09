import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_analytics/genrevibes_analytics.dart';
import 'package:genrevibes_app_rating/genrevibes_app_rating.dart';
import 'package:genrevibes_consent/genrevibes_consent.dart';
import 'package:genrevibes_crash/genrevibes_crash.dart';
import 'package:genrevibes_device_identity/genrevibes_device_identity.dart';
import 'package:genrevibes_engagement/genrevibes_engagement.dart';
import 'package:genrevibes_feedback/genrevibes_feedback.dart';
import 'package:genrevibes_iap/genrevibes_iap.dart';
import 'package:genrevibes_notifications/genrevibes_notifications.dart';
import 'package:genrevibes_onboarding/genrevibes_onboarding.dart';
import 'package:genrevibes_permissions/genrevibes_permissions.dart';
import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';
import 'package:genrevibes_starter_kit/genrevibes_starter_kit.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';

import 'dev_analytics_catalogue.dart';
import 'recording_delivery_observer.dart';
import 'recording_kit_logger.dart';

/// Everything the bench is allowed to touch.
///
/// The bench never reaches into a service locator, because it has to work in
/// any application in the portfolio and those disagree about how they wire
/// things up. The host passes what it has; every capability is nullable, and a
/// page whose capability is absent says so rather than crashing.
///
/// That also makes the bench a migration checklist: the capabilities showing
/// "not adopted" are exactly the ones still to be wired.
final class DevToolsHost {
  /// Creates a host.
  const DevToolsHost({
    required this.kit,
    required this.catalogue,
    this.logger,
    this.eventLog,
    this.analytics,
    this.ads,
    this.adPolicy,
    this.adPlacements = const <AdPlacement>[],
    this.consent,
    this.iap,
    this.push,
    this.permissions,
    this.remoteConfig,
    this.remoteConfigSchema,
    this.identity,
    this.retention,
    this.crash,
    this.feedback,
    this.store,
    this.storageKeys = const <DevStorageGroup>[],
    this.rating,
    this.onboarding,
    this.localNotifications,
  });

  /// The coordinator, for the module overview.
  final GenRevibesStarterKit kit;

  /// The application's analytics events.
  final DevAnalyticsCatalogue catalogue;

  /// Captured kit logs, when the application installed a recording logger.
  final RecordingKitLogger? logger;

  /// Captured analytics deliveries, when the application installed a recording
  /// observer. This is what DebugView cannot be made to do from app code.
  final RecordingDeliveryObserver? eventLog;

  /// Analytics pipeline.
  final AnalyticsPipeline? analytics;

  /// Full-screen ad provider.
  final AdProvider? ads;

  /// Ad policy, for showing why an ad is blocked.
  final AdPolicyController? adPolicy;

  /// Placements the application declares.
  final List<AdPlacement> adPlacements;

  /// Consent gate.
  final ConsentGate? consent;

  /// Purchases.
  final IapProvider? iap;

  /// Remote push.
  final PushNotificationProvider? push;

  /// Runtime permissions.
  final PermissionProvider? permissions;

  /// Typed remote configuration.
  final RemoteConfigCoordinator? remoteConfig;

  /// The schema behind [remoteConfig], so every key can be listed.
  final RemoteConfigSchema? remoteConfigSchema;

  /// Device identity.
  final DeviceIdentityResolver? identity;

  /// Retention and targeting.
  final RetentionTracker? retention;

  /// Crash reporting.
  final CrashCoordinator? crash;

  /// Feedback submission.
  final FeedbackProvider? feedback;

  /// Key-value storage, for the storage inspector.
  final KeyValueStore? store;

  /// Which keys the inspector should read.
  final List<DevStorageGroup> storageKeys;

  /// Rating coordinator.
  final RatingCoordinator? rating;

  /// Onboarding state.
  final OnboardingController? onboarding;

  /// Local notification scheduler.
  final LocalNotificationScheduler? localNotifications;
}

/// One capability's keys, for the storage inspector.
///
/// `KeyValueStore` has no way to enumerate what it holds, so the inspector
/// reads named keys. Pairing each with the legacy key it replaced is the whole
/// point: it shows whether a migration actually carried a user's data over.
final class DevStorageGroup {
  /// Creates a group.
  const DevStorageGroup({required this.title, required this.entries});

  /// Capability name.
  final String title;

  /// Keys to read.
  final List<DevStorageEntry> entries;
}

/// One key, and the legacy key it adopted from.
final class DevStorageEntry {
  /// Creates an entry.
  const DevStorageEntry({required this.key, this.legacyKey, this.label});

  /// The namespaced key the kit writes.
  final String key;

  /// The key this replaced, when there was one.
  final String? legacyKey;

  /// Optional human label.
  final String? label;
}
