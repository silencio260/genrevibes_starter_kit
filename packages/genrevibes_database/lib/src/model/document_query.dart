/// Comparison used by a [QueryFilter].
enum QueryOperator {
  /// Field equals the value.
  isEqualTo,

  /// Field does not equal the value.
  isNotEqualTo,

  /// Field is less than the value.
  isLessThan,

  /// Field is less than or equal to the value.
  isLessThanOrEqualTo,

  /// Field is greater than the value.
  isGreaterThan,

  /// Field is greater than or equal to the value.
  isGreaterThanOrEqualTo,

  /// Array field contains the value.
  arrayContains,

  /// Array field contains any of the values.
  arrayContainsAny,

  /// Field equals any of the values.
  whereIn,

  /// Field equals none of the values.
  whereNotIn,
}

/// One condition on a query.
final class QueryFilter {
  /// Creates a filter.
  const QueryFilter(this.field, this.operator, this.value);

  /// Field name.
  final String field;

  /// Comparison.
  final QueryOperator operator;

  /// Value compared against. A list for the set operators.
  final Object? value;

  /// Whether this operator expects a list value.
  bool get expectsList =>
      operator == QueryOperator.arrayContainsAny ||
      operator == QueryOperator.whereIn ||
      operator == QueryOperator.whereNotIn;
}

/// Sort order for a query.
final class QueryOrder {
  /// Creates an order.
  const QueryOrder(this.field, {this.descending = false});

  /// Field to sort by.
  final String field;

  /// Whether to sort descending.
  final bool descending;
}

/// A read against a collection.
final class DocumentQuery {
  /// Creates a query.
  DocumentQuery({
    List<QueryFilter> filters = const <QueryFilter>[],
    List<QueryOrder> orderBy = const <QueryOrder>[],
    this.limit,
  })  : filters = List<QueryFilter>.unmodifiable(filters),
        orderBy = List<QueryOrder>.unmodifiable(orderBy);

  /// Conditions, combined with AND.
  final List<QueryFilter> filters;

  /// Sort order, applied in list order.
  final List<QueryOrder> orderBy;

  /// Maximum documents to return.
  final int? limit;

  /// Whether this query would return the whole collection.
  bool get isUnbounded => filters.isEmpty && limit == null;

  /// Problems with this query, empty when it is well formed.
  ///
  /// A set operator given a scalar, or a non-positive limit, is a programming
  /// error that most stores report as an opaque runtime failure.
  List<String> validate() {
    final problems = <String>[];
    for (final filter in filters) {
      if (filter.expectsList && filter.value is! List) {
        problems.add(
          '${filter.operator.name} on "${filter.field}" expects a list value.',
        );
      }
    }
    final max = limit;
    if (max != null && max <= 0) problems.add('limit must be positive.');
    return problems;
  }
}
