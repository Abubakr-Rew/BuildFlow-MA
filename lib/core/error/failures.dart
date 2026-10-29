/// What went wrong, independent of how it is worded.
///
/// The UI turns a code into text (see `failure_messages.dart`); repositories
/// and the server never supply user-facing text. Codes follow the cases in
/// the fake repositories and docs/api-contract.md.
enum FailureCode {
  /// No internet connection or the request couldn't be sent.
  network,

  /// The request took too long.
  timeout,

  /// The server failed or is unreachable (5xx, API not available).
  server,

  /// Wrong email or password (login, 401).
  invalidCredentials,

  /// An account with this email already exists (register or join, 409).
  emailTaken,

  /// The invite code doesn't exist, was already used or has expired
  /// (join, 404).
  invalidInviteCode,

  /// No valid session; the user has to log in again (401).
  sessionExpired,

  /// The user's role doesn't allow the action (403).
  forbidden,

  /// The project, report or member doesn't exist (404).
  notFound,

  /// The server rejected the submitted data (400).
  validation,

  /// Too many attempts in a short time; the user should wait a minute
  /// before trying again (429, e.g. repeated invite codes on join).
  tooManyRequests,

  /// A picked photo couldn't be compressed on the device: an unsupported
  /// format (HEIC before Android 9), a damaged file or not enough memory.
  /// Comes from the client only, never from the API.
  photoProcessing,

  /// Anything else.
  unknown,
}

/// A failed operation. [code] decides what the user sees; [message] is for
/// logs and debugging only and is never shown in the UI.
///
/// Implements [Exception] so `AsyncNotifier.build()` can throw it into
/// `AsyncValue.error` as is.
final class Failure implements Exception {
  const Failure(this.code, {this.message, this.statusCode, this.stackTrace});

  final FailureCode code;
  final String? message;

  /// HTTP status, when the failure came from the API.
  final int? statusCode;
  final StackTrace? stackTrace;

  @override
  String toString() => message == null
      ? 'Failure(${code.name})'
      : 'Failure(${code.name}: $message)';
}
