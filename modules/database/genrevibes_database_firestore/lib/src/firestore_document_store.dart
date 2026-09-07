import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_database/genrevibes_database.dart';

import 'firestore_client.dart';

/// Cloud Firestore implementation of [DocumentStore].
///
/// Firebase must already be initialized by the host application before this
/// module starts.
final class FirestoreDocumentStore implements DocumentStore {
  /// Creates a Firestore document store.
  FirestoreDocumentStore({
    FirestoreClient? client,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _client = client ?? DefaultFirestoreClient(),
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'database',
          provider: 'firestore',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final FirestoreClient _client;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  ModuleHealth _health;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get providerId => 'firestore';

  @override
  String get moduleId => 'database';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  Future<KitResult<void>> initialize() async {
    if (_disposed) return _notReady<void>();
    if (_initialized) return const KitSuccess<void>(null);
    _initialized = true;
    _setHealth(ModuleState.ready);
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<DocumentSnapshot>> get(String path) {
    return _guardDocument(path, 'get', () => _client.get(path));
  }

  @override
  Future<KitResult<void>> set(
    String path,
    Map<String, Object?> data, {
    bool merge = false,
  }) {
    return _guardDocumentVoid(
      path,
      'set',
      () => _client.set(path, data, merge: merge),
    );
  }

  @override
  Future<KitResult<void>> update(String path, Map<String, Object?> data) {
    return _guardDocumentVoid(path, 'update', () => _client.update(path, data));
  }

  @override
  Future<KitResult<void>> delete(String path) {
    return _guardDocumentVoid(path, 'delete', () => _client.delete(path));
  }

  @override
  Future<KitResult<List<DocumentSnapshot>>> query(
    String collectionPath, [
    DocumentQuery? query,
  ]) async {
    if (!_initialized || _disposed) return _notReady<List<DocumentSnapshot>>();
    final resolved = query ?? DocumentQuery();
    final invalid = _validateCollection(collectionPath, resolved);
    if (invalid != null) return KitFailure<List<DocumentSnapshot>>(invalid);
    try {
      return KitSuccess<List<DocumentSnapshot>>(
        await _client.query(collectionPath, resolved),
      );
    } on Object catch (error, stackTrace) {
      return KitFailure<List<DocumentSnapshot>>(
        _map(error, stackTrace, 'query'),
      );
    }
  }

  @override
  Stream<DocumentSnapshot> watch(String path) {
    final invalid = DocumentPath.validateDocument(path);
    if (invalid != null) {
      return Stream<DocumentSnapshot>.error(
        _configurationError(invalid),
      );
    }
    return _client.watch(path);
  }

  @override
  Stream<List<DocumentSnapshot>> watchQuery(
    String collectionPath, [
    DocumentQuery? query,
  ]) {
    final resolved = query ?? DocumentQuery();
    final invalid = _validateCollection(collectionPath, resolved);
    if (invalid != null) {
      return Stream<List<DocumentSnapshot>>.error(invalid);
    }
    return _client.watchQuery(collectionPath, resolved);
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _disposed = true;
    _setHealth(ModuleState.disposed);
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  Future<KitResult<DocumentSnapshot>> _guardDocument(
    String path,
    String operation,
    Future<DocumentSnapshot> Function() action,
  ) async {
    if (!_initialized || _disposed) return _notReady<DocumentSnapshot>();
    final invalid = DocumentPath.validateDocument(path);
    if (invalid != null) {
      return KitFailure<DocumentSnapshot>(_configurationError(invalid));
    }
    try {
      return KitSuccess<DocumentSnapshot>(await action());
    } on Object catch (error, stackTrace) {
      return KitFailure<DocumentSnapshot>(_map(error, stackTrace, operation));
    }
  }

  Future<KitResult<void>> _guardDocumentVoid(
    String path,
    String operation,
    Future<void> Function() action,
  ) async {
    if (!_initialized || _disposed) return _notReady<void>();
    final invalid = DocumentPath.validateDocument(path);
    if (invalid != null) {
      return KitFailure<void>(_configurationError(invalid));
    }
    try {
      await action();
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      return KitFailure<void>(_map(error, stackTrace, operation));
    }
  }

  KitError? _validateCollection(String path, DocumentQuery query) {
    final invalidPath = DocumentPath.validateCollection(path);
    if (invalidPath != null) return _configurationError(invalidPath);
    final problems = query.validate();
    if (problems.isNotEmpty) {
      return _configurationError(problems.join(' '));
    }
    return null;
  }

  KitError _configurationError(String message) => KitError(
        code: KitErrorCode.invalidConfiguration,
        message: message,
      );

  KitError _map(Object error, StackTrace stackTrace, String operation) {
    final code = error is fs.FirebaseException ? error.code : '';
    final mapped = KitError(
      code: switch (code) {
        'unavailable' || 'deadline-exceeded' => KitErrorCode.network,
        'permission-denied' ||
        'unauthenticated' =>
          KitErrorCode.permissionDenied,
        'cancelled' => KitErrorCode.cancelled,
        _ => KitErrorCode.provider,
      },
      message: 'Firestore $operation failed: $error',
      providerCode: code.isEmpty ? 'firestore_$operation' : code,
      cause: error,
      stackTrace: stackTrace,
    );
    _logger.log(
      KitLogLevel.warning,
      'Firestore operation failed.',
      moduleId: moduleId,
      error: mapped,
    );
    if (!_disposed) _setHealth(ModuleState.degraded, error: mapped);
    return mapped;
  }

  KitFailure<T> _notReady<T>() {
    return KitFailure<T>(
      const KitError(
        code: KitErrorCode.notInitialized,
        message: 'Firestore document store has not been initialized.',
      ),
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: providerId,
      state: state,
      observedAt: _clock.now(),
      error: error,
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
