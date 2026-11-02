import 'dart:async';
import 'dart:io';

import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/supabase/supabase_failures.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Headers;

/// The one way the `Supabase*Repository` classes reach the backend: RPC,
/// Edge Functions and Storage files, every call as a [Result] with the
/// error already turned into a [Failure] (`failureFromSupabase`).
///
/// A data call that finds the session over (401, or 403 `account_removed`
/// / `no_profile`) signs out on this device and reports it on
/// [sessionEnded], as does Auth when it can't refresh the session any more
/// (refresh token revoked, user banned). `AuthNotifier` listens and the
/// router takes the user to the login screen.
class SupabaseGateway {
  SupabaseGateway(
    this.client, {
    required this.url,
    required this.anonKey,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _auth = client.auth.onAuthStateChange.listen(
      (state) {
        final involuntary = state.event == AuthChangeEvent.signedOut &&
            (state.signOutReason == SignOutReason.sessionExpired ||
                state.signOutReason == SignOutReason.sessionMissing);
        if (involuntary && !_signingOut) {
          _ended.add(
            const Failure(
              FailureCode.sessionExpired,
              message: 'Auth could not refresh the session',
            ),
          );
        }
      },
      // Auth also reports refresh errors here; the sign-out above covers
      // the ones that end the session.
      onError: (Object _) {},
    );
  }

  final SupabaseClient client;

  /// Project URL and anon key, for the Storage requests made with Dio.
  final String url;
  final String anonKey;

  final Dio _dio;
  late final StreamSubscription<AuthState> _auth;
  final _ended = StreamController<Failure>.broadcast();
  bool _signingOut = false;

  /// Fires when the session ended without the user signing out, with why.
  Stream<Failure> get sessionEnded => _ended.stream;

  /// The signed-in user's id, or `null`.
  String? get userId => client.auth.currentUser?.id;

  /// Calls `public.<function>` and parses its JSON with [parse].
  Future<Result<T>> rpc<T>(
    String function,
    T Function(Object? json) parse, {
    Map<String, dynamic>? params,
    SupabaseCall call = SupabaseCall.data,
  }) =>
      run(
        () async => parse(await client.rpc<Object?>(function, params: params)),
        call: call,
      );

  /// Calls the Edge Function [function] and parses its JSON with [parse].
  Future<Result<T>> invoke<T>(
    String function,
    T Function(Object? json) parse, {
    Object? body,
    Map<String, String>? headers,
    SupabaseCall call = SupabaseCall.data,
  }) =>
      run(
        () async {
          final response = await client.functions.invoke(
            function,
            body: body,
            headers: headers,
          );
          return parse(response.data);
        },
        call: call,
      );

  /// Runs [request], turning any error into a [Failure]. A data call
  /// without a session fails right away; one that finds the session over
  /// ends it (see the class doc).
  Future<Result<T>> run<T>(
    Future<T> Function() request, {
    SupabaseCall call = SupabaseCall.data,
  }) async {
    if (call == SupabaseCall.data && client.auth.currentSession == null) {
      return const Err(
        Failure(FailureCode.sessionExpired, message: 'Not signed in'),
      );
    }
    try {
      return Success(await request());
    } on Object catch (e, stackTrace) {
      final failure = failureFromSupabase(e, stackTrace: stackTrace, call: call);
      if (call == SupabaseCall.data && endsSession(failure)) {
        await endSession(failure);
      }
      return Err(failure);
    }
  }

  /// Ends the session on this device because of [failure] and says so on
  /// [sessionEnded].
  Future<void> endSession(Failure failure) async {
    if (_signingOut) return;
    _ended.add(failure);
    await signOut();
  }

  /// Signs out on this device; [sessionEnded] stays quiet. Offline, the
  /// local session goes anyway.
  Future<void> signOut() async {
    _signingOut = true;
    try {
      await client.auth.signOut();
    } on Object catch (e) {
      debugPrint('Sign-out request failed: $e');
    } finally {
      _signingOut = false;
    }
  }

  // ── Storage ────────────────────────────────────────────────

  /// Uploads [filePath] to [bucket]/[path] (from `create_upload`) with the
  /// user's token, reporting [onProgress] from 0 to 1. There's no
  /// overwrite: if an earlier attempt already stored the file, this one
  /// succeeds as is.
  Future<Result<void>> upload({
    required String bucket,
    required String path,
    required String filePath,
    required String contentType,
    ValueChanged<double>? onProgress,
  }) =>
      run(() async {
        final token = await _accessToken();
        final file = File(filePath);
        final length = await file.length();
        try {
          await _dio.post<Object?>(
            '$url/storage/v1/object/$bucket/$path',
            data: file.openRead(),
            options: Options(
              headers: {
                'Authorization': 'Bearer $token',
                'apikey': anonKey,
                Headers.contentTypeHeader: contentType,
                Headers.contentLengthHeader: length,
                'x-upsert': 'false',
              },
            ),
            onSendProgress: (sent, total) {
              final all = total > 0 ? total : length;
              if (all > 0) onProgress?.call((sent / all).clamp(0, 1));
            },
          );
        } on DioException catch (e) {
          if (!_isDuplicate(e.response)) rethrow;
        }
        onProgress?.call(1);
      });

  /// Signed links to [paths] of [bucket], valid [expiresIn]; paths the
  /// server wouldn't sign are left out.
  Future<Result<Map<String, String>>> signUrls(
    String bucket,
    List<String> paths, {
    required Duration expiresIn,
  }) =>
      run(() async {
        final signed = await client.storage
            .from(bucket)
            .createSignedUrlsResult(paths, expiresIn.inSeconds);
        return {
          for (final s in signed)
            if (s case SignedUrlSuccess(:final path, :final signedUrl))
              path: signedUrl,
        };
      });

  /// Downloads [signedUrl] into [savePath].
  Future<Result<void>> download(String signedUrl, String savePath) =>
      run(() async {
        await _dio.download(signedUrl, savePath);
      });

  /// A token valid for the next request: refreshed first if expired, e.g.
  /// right after the app comes back from the background.
  Future<String> _accessToken() async {
    var session = client.auth.currentSession;
    if (session != null && session.isExpired) {
      session = (await client.auth.refreshSession()).session;
    }
    final token = session?.accessToken;
    if (token == null) throw AuthSessionMissingException();
    return token;
  }

  /// Storage answers an existing object with 409, or with 400 and
  /// `statusCode: "409"` in the body, depending on the version.
  static bool _isDuplicate(Response<Object?>? response) {
    if (response == null) return false;
    if (response.statusCode == 409) return true;
    final body = response.data;
    return body is Map &&
        (body['statusCode'] == '409' || body['error'] == 'Duplicate');
  }

  Future<void> dispose() async {
    await _auth.cancel();
    await _ended.close();
    _dio.close();
  }
}
