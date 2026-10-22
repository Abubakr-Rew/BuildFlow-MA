/// Sealed failure hierarchy for type-safe error handling.
sealed class Failure {
  const Failure({required this.message, this.stackTrace});

  final String message;
  final StackTrace? stackTrace;

  @override
  String toString() => 'Failure: $message';
}

/// Network failures (timeout, connection, etc.)
final class NetworkFailure extends Failure {
  const NetworkFailure({required super.message, super.stackTrace});
}

/// Server returned an error response.
final class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    super.stackTrace,
    this.statusCode,
  });

  final int? statusCode;
}

/// Authentication-related failures.
final class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.stackTrace});
}

/// Local storage failures.
final class StorageFailure extends Failure {
  const StorageFailure({required super.message, super.stackTrace});
}

/// Validation or business-logic failures.
final class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.stackTrace});
}

/// An unexpected/unknown failure.
final class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'An unknown error occurred',
    super.stackTrace,
  });
}
