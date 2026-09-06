/// Resolves canonical event names to the names actually sent to sinks.
///
/// Kit packages emit events under stable canonical names (`retention_day_1_returned`,
/// `rating_submitted`, …). An application may need those names to differ per
/// provider or per remote configuration without every emitter knowing about it.
/// The pipeline applies this resolver once, so a renamed event reaches every
/// sink consistently.
abstract interface class AnalyticsEventNames {
  /// Returns the outgoing name for [canonicalName].
  ///
  /// Must return [canonicalName] unchanged when no override exists. Returning an
  /// empty string is a defect; the pipeline treats it as "no override".
  String resolve(String canonicalName);
}

/// Identity resolver: every event keeps its canonical name.
final class CanonicalAnalyticsEventNames implements AnalyticsEventNames {
  /// Creates the identity resolver.
  const CanonicalAnalyticsEventNames();

  @override
  String resolve(String canonicalName) => canonicalName;
}

/// Static map-backed resolver, useful for tests and simple per-app renames.
final class MappedAnalyticsEventNames implements AnalyticsEventNames {
  /// Creates a resolver over [overrides] keyed by canonical name.
  MappedAnalyticsEventNames(Map<String, String> overrides)
      : _overrides = Map<String, String>.unmodifiable(overrides);

  final Map<String, String> _overrides;

  @override
  String resolve(String canonicalName) {
    final override = _overrides[canonicalName];
    return override == null || override.trim().isEmpty
        ? canonicalName
        : override;
  }
}
