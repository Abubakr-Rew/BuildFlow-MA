import 'package:buildflow/core/error/failures.dart';

/// A Result type that represents either a success value or a failure.
/// Used throughout the domain and data layers for error handling
/// without exceptions.
sealed class Result<T> {
  const Result();

  /// Whether this is a successful result.
  bool get isSuccess => this is Success<T>;

  /// Whether this is a failure result.
  bool get isFailure => this is Err<T>;

  /// Returns the success value, or throws if this is a failure.
  T get value {
    return switch (this) {
      Success(:final data) => data,
      Err(:final failure) => throw StateError(
          'Cannot get value from Err: $failure',
        ),
    };
  }

  /// Returns the failure, or throws if this is a success.
  Failure get failure {
    return switch (this) {
      Success() => throw StateError('Cannot get failure from Success'),
      Err(:final failure) => failure,
    };
  }

  /// Transforms the success value using the given function.
  Result<U> map<U>(U Function(T data) fn) {
    return switch (this) {
      Success(:final data) => Success(fn(data)),
      Err(:final failure) => Err(failure),
    };
  }

  /// Transforms the success value using an async function.
  Future<Result<U>> mapAsync<U>(Future<U> Function(T data) fn) async {
    return switch (this) {
      Success(:final data) => Success(await fn(data)),
      Err(:final failure) => Err(failure),
    };
  }

  /// Applies the success or failure handler depending on the result.
  R when<R>({
    required R Function(T data) success,
    required R Function(Failure failure) failure,
  }) {
    return switch (this) {
      Success(:final data) => success(data),
      Err(failure: final f) => failure(f),
    };
  }
}

/// A successful result containing [data].
final class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;

  @override
  String toString() => 'Success($data)';
}

/// A failed result containing a [Failure].
final class Err<T> extends Result<T> {
  const Err(this.failure);

  @override
  final Failure failure;

  @override
  String toString() => 'Err($failure)';
}
