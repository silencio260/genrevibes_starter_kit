/// The kind of value a parameter carries, so the bench can offer the right
/// editor and encode it correctly.
enum DevParamKind {
  /// Free text.
  text,

  /// Whole number.
  integer,

  /// Decimal number.
  number,

  /// True or false.
  boolean,
}

/// One editable event parameter.
final class DevParamSpec {
  /// Creates a parameter description.
  const DevParamSpec({
    required this.name,
    required this.kind,
    required this.example,
    this.description,
  });

  /// Property name as it reaches the sinks.
  final String name;

  /// How to edit and encode it.
  final DevParamKind kind;

  /// A realistic starting value, so firing an event sends a plausible payload
  /// rather than an empty one.
  final Object example;

  /// Optional explanation.
  final String? description;
}

/// One analytics event an application can emit.
final class DevEventSpec {
  /// Creates an event description.
  const DevEventSpec({
    required this.name,
    this.description,
    this.group,
    this.parameters = const <DevParamSpec>[],
  });

  /// Event name exactly as production sends it.
  final String name;

  /// What triggers it in the real application.
  final String? description;

  /// Optional grouping label, used only to organise the list.
  final String? group;

  /// Parameters this event carries, beyond any the application always adds.
  final List<DevParamSpec> parameters;
}

/// Every event an application can emit, plus the properties it always attaches.
///
/// This exists so the bench and the emitters cannot disagree. The previous
/// bench kept its own hardcoded list, which drifted: six of its names were
/// emitted nowhere in the application, three were misspelled versions of real
/// ones, and it omitted the `platform` property every real event carries. It
/// was populating dashboards with events production never sends while never
/// exercising the ones it does.
final class DevAnalyticsCatalogue {
  /// Creates a catalogue.
  const DevAnalyticsCatalogue({
    required this.events,
    this.alwaysAttached = const <String, Object?>{},
  });

  /// Every event, in the order the bench should list them.
  final List<DevEventSpec> events;

  /// Properties the application attaches to every event it sends.
  ///
  /// Merged into each fired event so the bench sends the same shape production
  /// does.
  final Map<String, Object?> alwaysAttached;

  /// Distinct group labels, in first-seen order.
  List<String> get groups {
    final seen = <String>[];
    for (final event in events) {
      final group = event.group ?? 'Other';
      if (!seen.contains(group)) seen.add(group);
    }
    return seen;
  }

  /// Events belonging to [group].
  List<DevEventSpec> eventsIn(String group) => events
      .where((event) => (event.group ?? 'Other') == group)
      .toList(growable: false);
}
