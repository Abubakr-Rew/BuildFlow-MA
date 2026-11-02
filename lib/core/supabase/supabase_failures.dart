import 'dart:async';
import 'dart:io';

import 'package:buildflow/core/error/failures.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// What kind of call failed: the same answer means different things on
/// different endpoints (docs/api-contract.md, «Коды ошибок клиента»).
enum SupabaseCall {
  /// Sign-in, registration and session restore, with the `get_me` that
  /// follows them: a removed account is `accountDisabled` here.
  signIn,

  /// Edge Function `join`: 404 is a bad invite code.
  join,

  /// Everything else.
  data,
}

/// Turns an error of the Supabase clients (PostgREST, Auth, Edge Functions,
/// Storage) or of the network into a [Failure]. The machine reason of our
/// own errors is in `hint` (`private.fail(404, 'not_found')` → HTTP 404).
Failure failureFromSupabase(
  Object error, {
  StackTrace? stackTrace,
  SupabaseCall call = SupabaseCall.data,
}) {
  Failure fail(FailureCode code, {int? status}) => Failure(
        code,
        message: '$error',
        statusCode: status,
        stackTrace: stackTrace,
      );

  switch (error) {
    case Failure():
      return error;

    case PostgrestException(:final code, :final hint):
      final status = _postgrestStatus(code);
      if (status != null) {
        return fail(_byStatus(status, hint, call), status: status);
      }
      return fail(_bySqlState(code ?? ''));

    case FunctionException(:final status, :final details):
      return fail(_byStatus(status, _hintOf(details), call), status: status);

    case AuthRetryableFetchException(:final statusCode):
      final status = int.tryParse(statusCode ?? '');
      return fail(
        status != null && status >= 500
            ? FailureCode.server
            : FailureCode.network,
        status: status,
      );

    case AuthSessionMissingException():
      return fail(FailureCode.sessionExpired);

    case AuthException(:final code, :final statusCode):
      final status = int.tryParse(statusCode ?? '');
      return fail(_byAuthCode(code, status), status: status);

    case StorageException(:final statusCode, :final error):
      final status = int.tryParse(statusCode ?? '');
      if (status == null) return fail(FailureCode.unknown);
      return fail(_byStatus(status, error, call), status: status);

    case DioException(:final type, :final response):
      return switch (type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          fail(FailureCode.timeout),
        DioExceptionType.connectionError => fail(FailureCode.network),
        DioExceptionType.badResponse when response?.statusCode != null =>
          fail(
            _byStatus(response!.statusCode!, _hintOf(response.data), call),
            status: response.statusCode,
          ),
        _ when error.error is SocketException => fail(FailureCode.network),
        _ => fail(FailureCode.unknown),
      };

    case TimeoutException():
      return fail(FailureCode.timeout);

    case SocketException() ||
          HttpException() ||
          HandshakeException() ||
          http.ClientException():
      return fail(FailureCode.network);

    default:
      return fail(FailureCode.unknown);
  }
}

/// Whether [failure] means the session is over: the client signs out.
bool endsSession(Failure failure) =>
    failure.code == FailureCode.sessionExpired ||
    failure.code == FailureCode.accountDisabled;

/// `PT404` of `private.fail`, or a bare status when the body wasn't JSON.
int? _postgrestStatus(String? code) {
  if (code == null) return null;
  final match = RegExp(r'^(?:PT)?(\d{3})$').firstMatch(code);
  return match == null ? null : int.parse(match.group(1)!);
}

FailureCode _byStatus(int status, String? hint, SupabaseCall call) =>
    switch (status) {
      400 || 422 => FailureCode.validation,
      401 => FailureCode.sessionExpired,
      403 when hint == 'account_removed' && call != SupabaseCall.data =>
        FailureCode.accountDisabled,
      403 when hint == 'account_removed' || hint == 'no_profile' =>
        FailureCode.sessionExpired,
      403 => FailureCode.forbidden,
      404 when call == SupabaseCall.join || hint == 'invalid_invite_code' =>
        FailureCode.invalidInviteCode,
      404 => FailureCode.notFound,
      409 when call != SupabaseCall.data => FailureCode.emailTaken,
      409 => FailureCode.validation,
      413 => FailureCode.validation,
      429 => FailureCode.tooManyRequests,
      >= 500 => FailureCode.server,
      _ => FailureCode.unknown,
    };

/// PostgREST's own errors and SQL states that aren't ours.
FailureCode _bySqlState(String code) => switch (code) {
      // JWT missing, invalid or expired.
      'PGRST301' || 'PGRST302' || 'PGRST303' => FailureCode.sessionExpired,
      // No connection to the database.
      _ when code.startsWith('PGRST0') => FailureCode.server,
      // Malformed request: bad parameters, unknown filter.
      _ when code.startsWith('PGRST1') => FailureCode.validation,
      '42501' => FailureCode.forbidden,
      // Data exceptions and constraint violations: a bad uuid, a too long
      // value, a duplicate.
      _ when code.startsWith('22') || code.startsWith('23') =>
        FailureCode.validation,
      _ => FailureCode.server,
    };

FailureCode _byAuthCode(String? code, int? status) => switch (code) {
      'user_banned' => FailureCode.accountDisabled,
      'invalid_credentials' || 'invalid_grant' => FailureCode.invalidCredentials,
      'email_exists' || 'user_already_exists' => FailureCode.emailTaken,
      'weak_password' ||
      'validation_failed' ||
      'email_address_invalid' =>
        FailureCode.validation,
      'over_request_rate_limit' ||
      'over_email_send_rate_limit' =>
        FailureCode.tooManyRequests,
      'refresh_token_not_found' ||
      'refresh_token_already_used' ||
      'session_not_found' ||
      'session_expired' ||
      'session_missing' ||
      'bad_jwt' ||
      'no_authorization' =>
        FailureCode.sessionExpired,
      _ when status == 429 => FailureCode.tooManyRequests,
      _ when status != null && status >= 500 => FailureCode.server,
      _ => FailureCode.unknown,
    };

/// `hint` of an error body (`{error, hint}` of the Edge Functions), if any.
String? _hintOf(Object? body) => switch (body) {
      {'hint': final String hint} => hint,
      _ => null,
    };
