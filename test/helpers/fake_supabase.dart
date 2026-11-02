import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:buildflow/core/supabase/supabase_gateway.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Headers;

/// An answer of [FakeSupabase].
class FakeReply {
  const FakeReply(this.status, [this.body, this.headers = const {}]);

  /// JSON body of `private.fail(status, hint)`: `PT<status>` with the hint.
  FakeReply.fail(int status, String hint)
      : this(status, {
          'code': 'PT$status',
          'message': hint,
          'hint': hint,
          'details': null,
        });

  final int status;
  final Object? body;
  final Map<String, String> headers;
}

/// A request [FakeSupabase] saw.
class FakeRequest {
  FakeRequest(this.method, this.url, this.headers, this.body);

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final Object? body;

  /// The JSON body as a map (RPC parameters, function body).
  Map<String, dynamic> get json => (body as Map?)?.cast() ?? const {};
}

/// A real `SupabaseClient` and [SupabaseGateway] over a mocked HTTP client:
/// repository tests check the requests and how answers and errors map,
/// without a server. Storage uploads and downloads (Dio) go to the same
/// handlers.
class FakeSupabase {
  FakeSupabase() {
    client = SupabaseClient(
      url,
      'anon-key',
      httpClient: MockClient(_handleHttp),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final dio = Dio()..httpClientAdapter = _DioAdapter(this);
    gateway = SupabaseGateway(client, url: url, anonKey: 'anon-key', dio: dio);
  }

  static const url = 'http://supabase.test';

  late final SupabaseClient client;
  late final SupabaseGateway gateway;

  final requests = <FakeRequest>[];
  final _handlers = <String, FutureOr<FakeReply> Function(FakeRequest)>{};

  /// Answers `METHOD /path` (without the query) with [handler].
  void on(
    String method,
    String path,
    FutureOr<FakeReply> Function(FakeRequest request) handler,
  ) =>
      _handlers['$method $path'] = handler;

  /// `rpc/<name>` answers [json].
  void rpc(String name, Object? json) =>
      on('POST', '/rest/v1/rpc/$name', (_) => FakeReply(200, json));

  /// `rpc/<name>` fails like `private.fail(status, hint)`.
  void rpcFails(String name, int status, String hint) =>
      on('POST', '/rest/v1/rpc/$name', (_) => FakeReply.fail(status, hint));

  /// The Edge Function [name] answers [reply].
  void function(String name, FakeReply reply) =>
      on('POST', '/functions/v1/$name', (_) => reply);

  /// Parameters of every call of `rpc/<name>` so far.
  List<Map<String, dynamic>> rpcCalls(String name) => [
        for (final r in requests)
          if (r.url.path == '/rest/v1/rpc/$name') r.json,
      ];

  /// Requests to [path], any method.
  List<FakeRequest> requestsTo(String path) =>
      [for (final r in requests) if (r.url.path == path) r];

  /// Puts a valid session of [userId] into the client, as if signed in.
  Future<void> signIn(String userId, {String email = 'user@buildflow.kg'}) =>
      client.auth.recoverSession(jsonEncode(sessionJson(userId, email: email)));

  /// GoTrue's session JSON for [userId], with a token valid for an hour.
  static Map<String, dynamic> sessionJson(
    String userId, {
    String email = 'user@buildflow.kg',
  }) {
    final exp = DateTime.now().add(const Duration(hours: 1));
    String part(Map<String, Object?> json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    final token = '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
        '${part({
          'sub': userId,
          'role': 'authenticated',
          'exp': exp.millisecondsSinceEpoch ~/ 1000,
        })}.signature';
    return {
      'access_token': token,
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': exp.millisecondsSinceEpoch ~/ 1000,
      'refresh_token': 'refresh-$userId',
      'user': {
        'id': userId,
        'aud': 'authenticated',
        'email': email,
        'app_metadata': <String, Object?>{},
        'user_metadata': <String, Object?>{},
        'created_at': '2026-11-01T00:00:00Z',
      },
    };
  }

  Future<FakeReply> _reply(FakeRequest request) async {
    requests.add(request);
    final handler = _handlers['${request.method} ${request.url.path}'];
    if (handler == null) {
      return FakeReply(404, {
        'message': 'No fake for ${request.method} ${request.url.path}',
      });
    }
    return handler(request);
  }

  Future<http.Response> _handleHttp(http.Request request) async {
    final body = request.body.isEmpty ? null : _tryJson(request.body);
    final reply = await _reply(
      FakeRequest(request.method, request.url, request.headers, body),
    );
    return http.Response(
      reply.body == null ? '' : jsonEncode(reply.body),
      reply.status,
      headers: {'content-type': 'application/json', ...reply.headers},
      // PostgREST reads the method of the request back from the response.
      request: request,
    );
  }

  static Object? _tryJson(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return body;
    }
  }

  Future<void> dispose() async {
    await gateway.dispose();
    await client.dispose();
  }
}

/// Dio requests of the gateway (Storage uploads and downloads) go to the
/// handlers of [FakeSupabase]; the uploaded bytes are the request's body.
class _DioAdapter implements HttpClientAdapter {
  _DioAdapter(this._fake);

  final FakeSupabase _fake;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    final reply = await _fake._reply(
      FakeRequest(
        options.method,
        options.uri,
        {
          for (final e in options.headers.entries) e.key: '${e.value}',
        },
        bytes,
      ),
    );
    final body = reply.body;
    final data = body is List<int> ? body : utf8.encode(jsonEncode(body));
    return ResponseBody.fromBytes(
      data,
      reply.status,
      headers: {
        Headers.contentTypeHeader: [
          if (body is List<int>) 'application/octet-stream'
          else 'application/json',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
