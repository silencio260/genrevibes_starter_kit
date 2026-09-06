import 'package:genrevibes_core/genrevibes_core.dart';

import '../model/ad_placement.dart';

/// Reason an otherwise valid ad request must not be displayed.
enum AdPolicyBlockReason {
  /// Ads are disabled for this logical placement.
  placementDisabled,

  /// Customer currently has ad-free entitlement.
  premium,

  /// A paywall, onboarding flow, dialog, or other reason suppresses ads.
  suppressed,

  /// Another full-screen ad owns the display lock.
  anotherAdShowing,

  /// Initial session delay has not elapsed.
  initialDelay,

  /// Minimum interval since the previous display has not elapsed.
  frequencyCap,
}

/// Timing and enablement rules for one logical placement.
final class AdPlacementPolicy {
  /// Creates placement policy.
  const AdPlacementPolicy({
    this.enabled = true,
    this.initialDelay = Duration.zero,
    this.minimumInterval = Duration.zero,
  });

  /// Whether the placement is remotely/application enabled.
  final bool enabled;

  /// Minimum time after session start before the first display.
  final Duration initialDelay;

  /// Minimum time between successful displays.
  final Duration minimumInterval;
}

/// Decision returned by [AdPolicyController.evaluate].
final class AdPolicyDecision {
  /// Creates an allowed decision.
  const AdPolicyDecision.allowed() : blockReason = null;

  /// Creates a blocked decision.
  const AdPolicyDecision.blocked(this.blockReason);

  /// Blocking reason or `null` when allowed.
  final AdPolicyBlockReason? blockReason;

  /// Whether display may proceed.
  bool get isAllowed => blockReason == null;
}

/// Provider-neutral premium, suppression, concurrency, and frequency policy.
final class AdPolicyController {
  /// Creates an ad policy controller.
  AdPolicyController({
    Map<String, AdPlacementPolicy> placements =
        const <String, AdPlacementPolicy>{},
    AdPlacementPolicy defaultPolicy = const AdPlacementPolicy(),
    bool isPremium = false,
    KitClock clock = const SystemKitClock(),
  })  : _placements = Map<String, AdPlacementPolicy>.unmodifiable(placements),
        _defaultPolicy = defaultPolicy,
        _isPremium = isPremium,
        _clock = clock,
        _sessionStartedAt = clock.now();

  final Map<String, AdPlacementPolicy> _placements;
  final AdPlacementPolicy _defaultPolicy;
  final KitClock _clock;
  final Map<String, int> _suppressionCounts = <String, int>{};
  final Map<String, DateTime> _lastShownAt = <String, DateTime>{};
  DateTime _sessionStartedAt;
  bool _isPremium;
  AdPlacement? _showingPlacement;

  /// Whether the customer currently has ad-free entitlement.
  bool get isPremium => _isPremium;

  /// Active suppression reasons for diagnostics.
  Set<String> get suppressionReasons =>
      Set<String>.unmodifiable(_suppressionCounts.keys);

  /// Placement currently holding the full-screen display lock.
  AdPlacement? get showingPlacement => _showingPlacement;

  /// Updates ad-free entitlement state.
  void setPremium(bool value) => _isPremium = value;

  /// Adds a reference-counted suppression reason.
  void suppress(String reason) {
    final normalized = reason.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'Reason cannot be blank.');
    }
    _suppressionCounts.update(
      normalized,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  /// Releases one suppression reason.
  void release(String reason) {
    final normalized = reason.trim();
    final count = _suppressionCounts[normalized];
    if (count == null) return;
    if (count <= 1) {
      _suppressionCounts.remove(normalized);
    } else {
      _suppressionCounts[normalized] = count - 1;
    }
  }

  /// Runs [action] with ads suppressed, releasing even when it throws.
  Future<T> whileSuppressed<T>(
    String reason,
    Future<T> Function() action,
  ) async {
    suppress(reason);
    try {
      return await action();
    } finally {
      release(reason);
    }
  }

  /// Resets first-show timing for a new foreground/session boundary.
  void startSession() {
    _sessionStartedAt = _clock.now();
    _lastShownAt.clear();
  }

  /// Evaluates current policy without acquiring the display lock.
  AdPolicyDecision evaluate(AdPlacement placement) {
    final policy = _placements[placement.id] ?? _defaultPolicy;
    if (!policy.enabled) {
      return const AdPolicyDecision.blocked(
        AdPolicyBlockReason.placementDisabled,
      );
    }
    if (_isPremium) {
      return const AdPolicyDecision.blocked(AdPolicyBlockReason.premium);
    }
    if (_suppressionCounts.isNotEmpty) {
      return const AdPolicyDecision.blocked(AdPolicyBlockReason.suppressed);
    }
    if (_showingPlacement != null) {
      return const AdPolicyDecision.blocked(
        AdPolicyBlockReason.anotherAdShowing,
      );
    }
    final now = _clock.now();
    if (now.difference(_sessionStartedAt) < policy.initialDelay) {
      return const AdPolicyDecision.blocked(AdPolicyBlockReason.initialDelay);
    }
    final lastShownAt = _lastShownAt[placement.id];
    if (lastShownAt != null &&
        now.difference(lastShownAt) < policy.minimumInterval) {
      return const AdPolicyDecision.blocked(AdPolicyBlockReason.frequencyCap);
    }
    return const AdPolicyDecision.allowed();
  }

  /// Acquires the full-screen lock when policy allows [placement].
  AdPolicyDecision beginShow(AdPlacement placement) {
    final decision = evaluate(placement);
    if (decision.isAllowed) _showingPlacement = placement;
    return decision;
  }

  /// Records a successful display time.
  void recordShown(AdPlacement placement) {
    _lastShownAt[placement.id] = _clock.now();
  }

  /// Releases the display lock owned by [placement].
  void finishShow(AdPlacement placement) {
    if (_showingPlacement == placement) _showingPlacement = null;
  }
}
