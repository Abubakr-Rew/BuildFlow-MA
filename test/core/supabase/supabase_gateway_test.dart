import 'dart:io';

import 'package:buildflow/core/error/failures.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_supabase.dart';

void main() {
  late FakeSupabase supabase;

  setUp(() => supabase = FakeSupabase());
  tearDown(() => supabase.dispose());

  test('an RPC answer is parsed', () async {
    await supabase.signIn('u1');
    supabase.rpc('get_projects', [
      {'id': 'p1'},
    ]);

    final result = await supabase.gateway.rpc(
      'get_projects',
      (json) => (json! as List).length,
      params: {'p_x': 1},
    );

    expect(result.value, 1);
    expect(supabase.rpcCalls('get_projects').single, {'p_x': 1});
  });

  test('without a session a data call fails without a request', () async {
    final result = await supabase.gateway.rpc('get_projects', (j) => j);

    expect(result.failure.code, FailureCode.sessionExpired);
    expect(supabase.requests, isEmpty);
  });

  test('a removed account ends the session and says why', () async {
    await supabase.signIn('u1');
    supabase
      ..rpcFails('get_projects', 403, 'account_removed')
      ..on('POST', '/auth/v1/logout', (_) => const FakeReply(204));
    final ended = <Failure>[];
    supabase.gateway.sessionEnded.listen(ended.add);

    final result = await supabase.gateway.rpc('get_projects', (j) => j);

    expect(result.failure.code, FailureCode.sessionExpired);
    await pumpEventQueue();
    expect(ended.map((f) => f.code), [FailureCode.sessionExpired]);
    expect(supabase.client.auth.currentSession, isNull);
  });

  test('an ordinary 403 keeps the session', () async {
    await supabase.signIn('u1');
    supabase.rpcFails('create_project', 403, 'owner_only');
    final ended = <Failure>[];
    supabase.gateway.sessionEnded.listen(ended.add);

    final result = await supabase.gateway.rpc('create_project', (j) => j);

    expect(result.failure.code, FailureCode.forbidden);
    await pumpEventQueue();
    expect(ended, isEmpty);
    expect(supabase.client.auth.currentSession, isNotNull);
  });

  group('upload', () {
    late File file;

    setUp(() async {
      final dir = await Directory.systemTemp.createTemp('gateway_test');
      file = File('${dir.path}/photo.jpg')..writeAsBytesSync(List.filled(2048, 7));
      addTearDown(() => dir.delete(recursive: true));
    });

    test('sends the file with the token and reports progress', () async {
      await supabase.signIn('u1');
      supabase.on(
        'POST',
        '/storage/v1/object/photos/c/u1/a1.jpg',
        (_) => const FakeReply(200, {'Key': 'photos/c/u1/a1.jpg'}),
      );
      final progress = <double>[];

      final result = await supabase.gateway.upload(
        bucket: 'photos',
        path: 'c/u1/a1.jpg',
        filePath: file.path,
        contentType: 'image/jpeg',
        onProgress: progress.add,
      );

      expect(result.isSuccess, isTrue);
      final request = supabase.requests.single;
      expect(request.headers['Authorization'], startsWith('Bearer '));
      expect(request.headers['content-type'], 'image/jpeg');
      expect((request.body! as List<int>).length, 2048);
      expect(progress.last, 1);
    });

    test('a file stored by an earlier attempt counts as uploaded', () async {
      await supabase.signIn('u1');
      supabase.on(
        'POST',
        '/storage/v1/object/photos/c/u1/a1.jpg',
        (_) => const FakeReply(400, {
          'statusCode': '409',
          'error': 'Duplicate',
          'message': 'The resource already exists',
        }),
      );

      final result = await supabase.gateway.upload(
        bucket: 'photos',
        path: 'c/u1/a1.jpg',
        filePath: file.path,
        contentType: 'image/jpeg',
      );

      expect(result.isSuccess, isTrue);
    });

    test('a refused upload is a failure', () async {
      await supabase.signIn('u1');
      supabase.on(
        'POST',
        '/storage/v1/object/photos/c/u1/a1.jpg',
        (_) => const FakeReply(403, {'statusCode': '403', 'error': 'Unauthorized'}),
      );

      final result = await supabase.gateway.upload(
        bucket: 'photos',
        path: 'c/u1/a1.jpg',
        filePath: file.path,
        contentType: 'image/jpeg',
      );

      expect(result.failure.code, FailureCode.forbidden);
    });
  });
}
