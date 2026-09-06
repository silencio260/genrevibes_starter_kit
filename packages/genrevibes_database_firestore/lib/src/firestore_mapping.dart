import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:genrevibes_database/genrevibes_database.dart';

/// Converts a Firestore document into a neutral snapshot.
DocumentSnapshot mapDocument(
  String path,
  fs.DocumentSnapshot<Map<String, dynamic>> document,
) {
  if (!document.exists) return DocumentSnapshot.missing(path);
  return DocumentSnapshot(
    path: path,
    data: document.data(),
    isFromCache: document.metadata.isFromCache,
  );
}

/// Applies a neutral [query] to a Firestore collection reference.
fs.Query<Map<String, dynamic>> applyQuery(
  fs.Query<Map<String, dynamic>> reference,
  DocumentQuery query,
) {
  var result = reference;
  for (final filter in query.filters) {
    result = _applyFilter(result, filter);
  }
  for (final order in query.orderBy) {
    result = result.orderBy(order.field, descending: order.descending);
  }
  final limit = query.limit;
  return limit == null ? result : result.limit(limit);
}

fs.Query<Map<String, dynamic>> _applyFilter(
  fs.Query<Map<String, dynamic>> reference,
  QueryFilter filter,
) {
  final field = filter.field;
  final value = filter.value;
  return switch (filter.operator) {
    QueryOperator.isEqualTo => reference.where(field, isEqualTo: value),
    QueryOperator.isNotEqualTo => reference.where(field, isNotEqualTo: value),
    QueryOperator.isLessThan => reference.where(field, isLessThan: value),
    QueryOperator.isLessThanOrEqualTo =>
      reference.where(field, isLessThanOrEqualTo: value),
    QueryOperator.isGreaterThan => reference.where(field, isGreaterThan: value),
    QueryOperator.isGreaterThanOrEqualTo =>
      reference.where(field, isGreaterThanOrEqualTo: value),
    QueryOperator.arrayContains => reference.where(field, arrayContains: value),
    QueryOperator.arrayContainsAny =>
      reference.where(field, arrayContainsAny: value as List<Object?>),
    QueryOperator.whereIn =>
      reference.where(field, whereIn: value as List<Object?>),
    QueryOperator.whereNotIn =>
      reference.where(field, whereNotIn: value as List<Object?>),
  };
}
