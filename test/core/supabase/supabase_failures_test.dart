import 'dart:async';
import 'dart:io';

import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/supabase/supabase_failures.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException _pt(int status, String hint) =>
    PostgrestException(message: hint, code: 'PT$status', hint: hint);

void main() {
  FailureCode code(Object error, [SupabaseCall call = SupabaseCall.data]) =>
      failureFromSupabase(error, call: call).code;

  group('PostgREST: our errors by status and hint', () {
    test('status', () {
      expect(code(_pt(400, 'invalid_text')), FailureCode.validation);
      expect(code(_pt(401, 'not_authenticated')), FailureCode.sessionExpired);
      expect(code(_pt(403, 'owner_only')), FailureCode.forbidden);
      expect(code(_pt(403, 'attachment_forbidden')), FailureCode.forbidden);
      expect(code(_pt(404, 'not_found')), FailureCode.notFound);
      expect(code(_pt(429, 'too_many_requests')), FailureCode.tooManyRequests);
      expect(code(_pt(500, 'oops')), FailureCode.server);
    });

    test('a removed account or a missing profile ends the session', () {
      expect(code(_pt(403, 'account_removed')), FailureCode.sessionExpired);
      expect(code(_pt(403, 'no_profile')), FailureCode.sessionExpired);
      expect(
        endsSession(failureFromSupabase(_pt(403, 'account_removed'))),
        isTrue,
      );
    });

    test('while signing in a removed account is disabled', () {
      expect(
        code(_pt(403, 'account_removed'), SupabaseCall.signIn),
        FailureCode.accountDisabled,
      );
      expect(
        code(_pt(403, 'no_profile'), SupabaseCall.signIn),
        FailureCode.sessionExpired,
      );
    });

    test('a bad invite code', () {
      expect(
        code(_pt(404, 'invalid_invite_code')),
        FailureCode.invalidInviteCode,
      );
    });

    test('PostgREST and SQL states', () {
      PostgrestException e(String code) =>
          PostgrestException(message: code, code: code);
      expect(code(e('PGRST301')), FailureCode.sessionExpired);
      expect(code(e('PGRST303')), FailureCode.sessionExpired);
      expect(code(e('PGRST002')), FailureCode.server);
      expect(code(e('PGRST100')), FailureCode.validation);
      expect(code(e('22P02')), FailureCode.validation);
      expect(code(e('23505')), FailureCode.validation);
      expect(code(e('42501')), FailureCode.forbidden);
      expect(code(e('XX000')), FailureCode.server);
      // No JSON body: the bare HTTP status.
      expect(code(e('502')), FailureCode.server);
    });
  });

  group('Auth', () {
    AuthException e(String code, [String status = '400']) =>
        AuthApiException(code, code: code, statusCode: status);

    test('sign-in', () {
      expect(code(e('invalid_credentials')), FailureCode.invalidCredentials);
      expect(code(e('user_banned')), FailureCode.accountDisabled);
      expect(code(e('user_already_exists', '422')), FailureCode.emailTaken);
      expect(code(e('email_exists', '422')), FailureCode.emailTaken);
      expect(code(e('weak_password', '422')), FailureCode.validation);
      expect(
        code(e('over_request_rate_limit', '429')),
        FailureCode.tooManyRequests,
      );
      expect(code(e('unexpected_failure', '500')), FailureCode.server);
    });

    test('session', () {
      expect(code(e('refresh_token_not_found')), FailureCode.sessionExpired);
      expect(code(AuthSessionMissingException()), FailureCode.sessionExpired);
    });

    test('network', () {
      expect(
        code(AuthRetryableFetchException(message: 'Failed host lookup')),
        FailureCode.network,
      );
      expect(
        code(AuthRetryableFetchException(message: 'bad gateway', statusCode: '502')),
        FailureCode.server,
      );
    });
  });

  group('Edge Functions', () {
    FunctionException e(int status, [String? hint]) => FunctionException(
          status: status,
          details: {'error': 'x', 'hint': ?hint},
        );

    test('join', () {
      expect(code(e(404), SupabaseCall.join), FailureCode.invalidInviteCode);
      expect(code(e(409), SupabaseCall.join), FailureCode.emailTaken);
      expect(code(e(429), SupabaseCall.join), FailureCode.tooManyRequests);
      expect(code(e(400), SupabaseCall.join), FailureCode.validation);
      expect(code(e(500), SupabaseCall.join), FailureCode.server);
    });

    test('remove-member', () {
      expect(code(e(404, 'not_found')), FailureCode.notFound);
      expect(code(e(403, 'owner_only')), FailureCode.forbidden);
      expect(code(e(401, 'not_authenticated')), FailureCode.sessionExpired);
    });
  });

  group('Storage and the network', () {
    test('Storage errors by status', () {
      expect(
        code(const StorageException('denied', statusCode: '403')),
        FailureCode.forbidden,
      );
      expect(
        code(const StorageException('too big', statusCode: '413')),
        FailureCode.validation,
      );
    });

    test('Dio', () {
      final options = RequestOptions(path: '/storage');
      expect(
        code(DioException.connectionError(requestOptions: options, reason: 'x')),
        FailureCode.network,
      );
      expect(
        code(
          DioException.sendTimeout(
            timeout: const Duration(seconds: 1),
            requestOptions: options,
          ),
        ),
        FailureCode.timeout,
      );
      expect(
        code(
          DioException.badResponse(
            statusCode: 403,
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 403),
          ),
        ),
        FailureCode.forbidden,
      );
    });

    test('no connection or no answer', () {
      expect(code(const SocketException('no route')), FailureCode.network);
      expect(code(http.ClientException('closed')), FailureCode.network);
      expect(code(TimeoutException('slow')), FailureCode.timeout);
      expect(code(StateError('bug')), FailureCode.unknown);
    });
  });
}
