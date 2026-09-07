import '../error/kit_error.dart';

/// The result of an operation that can fail with a normalized [KitError].
sealed class KitResult<T> {
  const KitResult();

  /// Whether this result contains a successful value.
  bool get isSuccess => this is KitSuccess<T>;

  /// Whether this result contains an error.
  bool get isFailure => this is KitFailure<T>;

  /// Transforms a successful value while preserving a failure.
  KitResult<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      KitSuccess<T>(:final value) => KitSuccess<R>(transform(value)),
      KitFailure<T>(:final error) => KitFailure<R>(error),
    };
  }

  /// Handles both possible result states.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(KitError error) onFailure,
  }) {
    return switch (this) {
      KitSuccess<T>(:final value) => onSuccess(value),
      KitFailure<T>(:final error) => onFailure(error),
    };
  }
}

/// A successful [KitResult].
final class KitSuccess<T> extends KitResult<T> {
  /// Creates a successful result containing [value].
  const KitSuccess(this.value);

  /// The operation result.
  final T value;
}

/// A failed [KitResult].
final class KitFailure<T> extends KitResult<T> {
  /// Creates a failed result containing [error].
  const KitFailure(this.error);

  /// The normalized operation error.
  final KitError error;
}
