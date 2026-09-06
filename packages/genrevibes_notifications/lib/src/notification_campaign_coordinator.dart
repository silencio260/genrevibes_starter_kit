import 'package:genrevibes_core/genrevibes_core.dart';

import 'local_notification_scheduler.dart';
import 'model/local_notification.dart';
import 'notification_campaign_source.dart';

/// Applies a campaign source without coupling notification packages to remote config.
final class NotificationCampaignCoordinator {
  /// Creates a campaign coordinator.
  const NotificationCampaignCoordinator({
    required this.scheduler,
    required this.source,
    this.managedIds = const <int>{},
  });

  /// Selected local notification implementation.
  final LocalNotificationScheduler scheduler;

  /// Static, remote, or layered campaign input.
  final NotificationCampaignSource source;

  /// Reserved IDs this coordinator may cancel during reconciliation.
  ///
  /// Leave empty when refresh should only add or replace desired campaigns.
  final Set<int> managedIds;

  /// Loads and schedules all desired campaigns.
  ///
  /// Duplicate identifiers and partial provider failures are returned instead
  /// of silently producing an ambiguous schedule.
  Future<KitResult<void>> refresh() async {
    List<LocalNotificationRequest> requests;
    try {
      requests = await source.loadCampaigns();
    } on Object catch (error, stackTrace) {
      return KitFailure<void>(
        KitError(
          code: KitErrorCode.unavailable,
          message: 'Notification campaign source failed: $error',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }

    final ids = <int>{};
    for (final request in requests) {
      if (!ids.add(request.id)) {
        return KitFailure<void>(
          KitError(
            code: KitErrorCode.invalidConfiguration,
            message: 'Duplicate local notification id: ${request.id}.',
          ),
        );
      }
      if (managedIds.isNotEmpty && !managedIds.contains(request.id)) {
        return KitFailure<void>(
          KitError(
            code: KitErrorCode.invalidConfiguration,
            message:
                'Local notification id ${request.id} is outside the managed set.',
          ),
        );
      }
    }

    if (managedIds.isNotEmpty) {
      final pendingResult = await scheduler.pending();
      final pending = pendingResult.fold<List<PendingLocalNotification>?>(
        onSuccess: (value) => value,
        onFailure: (_) => null,
      );
      if (pending == null) {
        return pendingResult.fold(
          onSuccess: (_) => const KitSuccess<void>(null),
          onFailure: KitFailure<void>.new,
        );
      }
      for (final item in pending) {
        if (managedIds.contains(item.id) && !ids.contains(item.id)) {
          final result = await scheduler.cancel(item.id);
          if (result case KitFailure<void>()) return result;
        }
      }
    }

    for (final request in requests) {
      final result = await scheduler.schedule(request);
      if (result case KitFailure<void>()) return result;
    }
    return const KitSuccess<void>(null);
  }
}
