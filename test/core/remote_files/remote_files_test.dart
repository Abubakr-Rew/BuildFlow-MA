import 'dart:io';

import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/remote_files/remote_files.dart';
import 'package:buildflow/core/remote_files/storage_ref.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_supabase.dart';

void main() {
  late FakeSupabase supabase;
  late Directory cache;
  late DateTime now;
  late RemoteFiles files;
  var token = 0;

  const a1 = StorageRef('photos', 'c1/u1/a1.jpg');
  const a2 = StorageRef('photos', 'c1/u1/a2.jpg');

  setUp(() async {
    supabase = FakeSupabase();
    await supabase.signIn('u1');
    cache = await Directory.systemTemp.createTemp('remote_files_test');
    now = DateTime(2026, 11, 2, 12);
    token = 0;
    files = RemoteFiles(
      gateway: supabase.gateway,
      cacheDir: () async => cache.path,
      now: () => now,
    );
    // Signing: a fresh token per request; downloads: the path's bytes.
    supabase.on('POST', '/storage/v1/object/sign/photos', (request) {
      token++;
      return FakeReply(200, [
        for (final path in request.json['paths'] as List)
          {'path': path, 'signedURL': '/object/sign/photos/$path?token=t$token', 'error': null},
      ]);
    });
    for (final ref in [a1, a2]) {
      supabase.on(
        'GET',
        '/storage/v1/object/sign/photos/${ref.path}',
        (_) => FakeReply(200, ref.attachmentId.codeUnits),
      );
    }
  });
  tearDown(() async {
    await supabase.dispose();
    await cache.delete(recursive: true);
  });

  List<FakeRequest> signs() => supabase.requestsTo('/storage/v1/object/sign/photos');
  List<FakeRequest> downloads(StorageRef ref) =>
      supabase.requestsTo('/storage/v1/object/sign/photos/${ref.path}');

  test('downloads once into the cache, keyed by attachment', () async {
    final path = (await files.localPath(a1)).value;

    expect(path, '${cache.path}/remote/a1.jpg');
    expect(File(path).readAsStringSync(), 'a1');

    await files.localPath(a1);
    expect(downloads(a1), hasLength(1));
    expect(signs(), hasLength(1));
  });

  test('photos shown together are signed with one request', () async {
    await Future.wait([files.localPath(a1), files.localPath(a2)]);

    expect(signs().single.json['paths'], ['c1/u1/a1.jpg', 'c1/u1/a2.jpg']);
    expect(signs().single.json['expiresIn'], 3600);
  });

  test('a link is reused until shortly before it expires', () async {
    expect((await files.signedUrl(a1)).value, contains('token=t1'));

    now = now.add(const Duration(minutes: 50));
    expect((await files.signedUrl(a1)).value, contains('token=t1'));

    now = now.add(const Duration(minutes: 6));
    expect((await files.signedUrl(a1)).value, contains('token=t2'));
  });

  test('a refused link is signed again once', () async {
    var attempts = 0;
    supabase.on('GET', '/storage/v1/object/sign/photos/${a1.path}', (request) {
      attempts++;
      return request.url.queryParameters['token'] == 't1'
          ? const FakeReply(400, {'statusCode': '400', 'error': 'InvalidJWT'})
          : FakeReply(200, 'a1'.codeUnits);
    });

    final result = await files.localPath(a1);

    expect(result.isSuccess, isTrue);
    expect(attempts, 2);
    expect(signs(), hasLength(2));
  });

  test('a file that cannot be had is a failure, and nothing is cached', () async {
    supabase.on(
      'GET',
      '/storage/v1/object/sign/photos/${a1.path}',
      (_) => throw const SocketException('offline'),
    );

    final result = await files.localPath(a1);

    expect(result.failure.code, FailureCode.network);
    final dir = Directory('${cache.path}/remote');
    expect(dir.existsSync() ? dir.listSync() : const <FileSystemEntity>[], isEmpty);
  });

  test("the user's own upload is never downloaded back", () async {
    final upload = File('${cache.path}/upload.jpg')..writeAsStringSync('mine');

    await files.adopt(a1, upload.path);
    final path = (await files.localPath(a1)).value;

    expect(File(path).readAsStringSync(), 'mine');
    expect(supabase.requests, isEmpty);
  });

  test('clear forgets the files and the links', () async {
    await files.localPath(a1);

    await files.clear();

    expect(Directory('${cache.path}/remote').existsSync(), isFalse);
    await files.localPath(a1);
    expect(signs(), hasLength(2));
    expect(downloads(a1), hasLength(2));
  });

  test('sweep deletes old files and the oldest over the limit', () async {
    final dir = Directory('${cache.path}/remote')..createSync();
    File write(String name, int bytes, Duration age) =>
        File('${dir.path}/$name')
          ..writeAsBytesSync(List.filled(bytes, 1))
          ..setLastModifiedSync(now.subtract(age));
    final old = write('old.jpg', 10, const Duration(days: 40));
    final big = write('big.jpg', 600, const Duration(days: 2));
    final fresh = write('fresh.jpg', 500, const Duration(hours: 1));
    final part = write('x.jpg.1.part', 10, Duration.zero);

    await files.sweep(maxBytes: 1000);

    expect(old.existsSync(), isFalse);
    expect(big.existsSync(), isFalse, reason: 'over the limit, used longest ago');
    expect(fresh.existsSync(), isTrue);
    expect(part.existsSync(), isFalse);
  });
}
