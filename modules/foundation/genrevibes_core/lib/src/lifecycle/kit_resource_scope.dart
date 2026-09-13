import 'dart:async';

import '../error/kit_error.dart';
import '../result/kit_result.dart';
import 'starter_module.dart';

/// Owns cleanup callbacks in reverse creation order. Safe to close repeatedly.
final class KitResourceScope {
  /// Creates a scope with a separate timeout for each cleanup callback.
  KitResourceScope({this.cleanupTimeout = const Duration(seconds: 5)});

  /// Maximum wait per callback before proceeding to the next resource.
  final Duration cleanupTimeout;
  final List<FutureOr<void> Function()> _cleanups = [];
  bool _closed = false;
  Future<KitResult<void>>? _disposal;

  /// Whether disposal has begun and new startup work must stop.
  bool get isClosed => _closed;

  /// Throws when startup attempts to continue after this scope was closed.
  void ensureActive() {
    if (_closed) throw StateError('This runtime has been stopped.');
  }

  /// Register immediately after construction, before awaiting initialization.
  void add(FutureOr<void> Function() cleanup) {
    if (_closed) {
      // A resource constructed by late startup work still belongs to this scope.
      unawaited(Future<void>.sync(cleanup)
          .timeout(cleanupTimeout)
          .catchError((Object _) {}));
      ensureActive();
    }
    _cleanups.add(cleanup);
  }

  /// Own a module and preserve failures returned by its cleanup contract.
  void addModule(StarterModule module) => add(() async {
        final result = await module.dispose();
        result.fold(onSuccess: (_) {}, onFailure: (error) => throw error);
      });

  /// Stops the scope and performs all cleanup callbacks in reverse order.
  Future<KitResult<void>> dispose() {
    _closed = true;
    return _disposal ??= _dispose();
  }

  Future<KitResult<void>> _dispose() async {
    KitError? firstError;
    for (final cleanup in _cleanups.reversed.toList()) {
      try {
        await Future<void>.sync(cleanup).timeout(cleanupTimeout);
      } on Object catch (error, stack) {
        firstError ??= KitError(
          code: error is TimeoutException
              ? KitErrorCode.timeout
              : KitErrorCode.unknown,
          message: 'Runtime cleanup failed.',
          cause: error,
          stackTrace: stack,
        );
      }
    }
    _cleanups.clear();
    return firstError == null
        ? const KitSuccess<void>(null)
        : KitFailure<void>(firstError);
  }
}
