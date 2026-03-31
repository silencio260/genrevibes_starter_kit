import 'package:flutter/foundation.dart';
import 'package:starter_kit/starter_kit.dart';
import '../entities/subscription_status.dart';

/// Manages subscription state and provides a simple interface for the UI
///
/// mirrors the functionality of the SubscriptionManager in the Story Saver template.
class SubscriptionManager extends ChangeNotifier {
  // Singleton pattern
  static final SubscriptionManager _instance = SubscriptionManager._internal();
  factory SubscriptionManager() => _instance;
  SubscriptionManager._internal();

  static SubscriptionManager get instance => _instance;

  SubscriptionStatus _status = const SubscriptionStatus.free();
  bool _debugOverridePremium = false;

  /// Returns true if user is premium OR if debug override is enabled
  bool get isPremium => _debugOverridePremium || _status.isPremium;

  /// Current subscription status
  SubscriptionStatus get status => _status;

  /// Whether debug override is active
  bool get debugOverridePremium => _debugOverridePremium;

  /// Update the subscription status (called by IapBloc)
  void updateStatus(SubscriptionStatus newStatus, {bool debugLog = false}) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
      if (debugLog) {
        StarterLog.i(
          'Subscription Status Updated',
          tag: 'IAP',
          debugLog: true,
          values: {
            'Is Premium': isPremium,
            'Entitlement': _status.activeEntitlementId ?? 'none',
          },
        );
      }
    }
  }

  /// Toggle debug premium override
  void setDebugOverride(bool value) {
    if (_debugOverridePremium != value) {
      _debugOverridePremium = value;
      notifyListeners();
      debugPrint(
        'SubscriptionManager: Debug override set to $value - isPremium: $isPremium',
      );
    }
  }

  /// Reset manager
  void reset() {
    _status = const SubscriptionStatus.free();
    _debugOverridePremium = false;
    notifyListeners();
  }
}
