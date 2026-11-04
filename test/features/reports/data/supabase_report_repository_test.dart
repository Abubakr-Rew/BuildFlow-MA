import 'dart:io';

import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/photos/compressed_photo.dart';
import 'package:buildflow/core/supabase/supabase_uploads.dart';
import 'package:buildflow/features/reports/data/supabase_report_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_supabase.dart';

Map<String, dynamic> _report({List<Map<String, Object?>> photos = const []}) => {
      'id': 'r1',
      'projectId': 'p1',
      'projectName': 'Ала-Тоо',
      'authorId': 'f1',
      'authorName': 'Бакыт Касымов',
      'text': 'Залили плиту',
      'photos': photos,
      'createdAt': '2026-11-02T08:30:00Z',
    };

void main() {
  late FakeSupabase supabase;
  late SupabaseReportRepository repo;
  late Directory dir;

  setUp(() async {
    supabase = FakeSupabase();
    await supabase.signIn('f1');
    repo = SupabaseReportRepository(
      gateway: supabase.gateway,
      uploads: SupabaseUploads(supabase.gateway),
    );
    dir = await Directory.systemTemp.createTemp('report_repo_test');
  });
  tearDown(() async {
    await supabase.dispose();
    await dir.delete(recursive: true);
  });

  CompressedPhoto photo(String name, {DateTime? takenAt}) {
    final file = File('${dir.path}/$name')..writeAsBytesSync([1, 2, 3]);
    return CompressedPhoto(
      path: file.path,
      width: 1600,
      height: 1200,
      bytes: 3,
      takenAt: takenAt,
    );
  }

  var uploads = 0;
  void acceptUploads() {
    uploads = 0;
    supabase
      ..on('POST', '/rest/v1/rpc/create_upload', (_) {
        uploads++;
        return FakeReply(200, {
          'attachmentId': 'a$uploads',
          'bucket': 'photos',
          'path': 'c1/f1/a$uploads.jpg',
        });
      })
      ..on('POST', '/storage/v1/object/photos/c1/f1/a1.jpg', (_) => const FakeReply(200, {}))
      ..on('POST', '/storage/v1/object/photos/c1/f1/a2.jpg', (_) => const FakeReply(200, {}));
  }

  test('report photos come as storage links from bucket and path', () async {
    supabase.rpc('get_reports', [
      _report(
        photos: [
          {
            'id': 'a1',
            'bucket': 'photos',
            'path': 'c1/f1/a1.jpg',
            'takenAt': '2026-11-02T06:12:40Z',
          },
        ],
      ),
    ]);

    final photo = (await repo.getReports()).value.single.photos.single;

    expect(photo.url, 'storage:photos/c1/f1/a1.jpg');
    expect(photo.takenAt, DateTime.utc(2026, 11, 2, 6, 12, 40));
  });

  test('by project', () async {
    supabase.rpc('get_reports', [_report()]);

    await repo.getReportsByProject('p1');

    expect(supabase.rpcCalls('get_reports').single, {'p_project_id': 'p1'});
  });

  test('a report uploads its photos, then refers to them', () async {
    acceptUploads();
    supabase.rpc('submit_report', _report());
    final taken = DateTime.utc(2026, 11, 2, 6, 12, 40);

    final result = await repo.submitReport(
      projectId: 'p1',
      projectName: 'Ала-Тоо',
      authorId: 'f1',
      authorName: 'Бакыт',
      text: ' Залили плиту ',
      photos: [photo('1.jpg', takenAt: taken), photo('2.jpg')],
    );

    expect(result.isSuccess, isTrue);
    expect(supabase.rpcCalls('create_upload').first, {
      'p_content_type': 'image/jpeg',
      'p_bytes': 3,
      'p_width': 1600,
      'p_height': 1200,
    });
    expect(supabase.requestsTo('/storage/v1/object/photos/c1/f1/a1.jpg'), hasLength(1));
    expect(supabase.rpcCalls('submit_report').single, {
      'p_project_id': 'p1',
      'p_text': 'Залили плиту',
      'p_photos': [
        {'attachmentId': 'a1', 'takenAt': '2026-11-02T06:12:40.000Z'},
        {'attachmentId': 'a2', 'takenAt': null},
      ],
    });
  });

  test('a retried report does not upload its photos again', () async {
    acceptUploads();
    supabase.rpcFails('submit_report', 500, 'oops');
    final photos = [photo('1.jpg')];

    Future<void> submit() => repo.submitReport(
          projectId: 'p1',
          projectName: '',
          authorId: 'f1',
          authorName: '',
          text: '',
          photos: photos,
        );

    await submit();
    supabase.rpc('submit_report', _report());
    await submit();

    expect(supabase.rpcCalls('create_upload'), hasLength(1));
    expect(supabase.rpcCalls('submit_report'), hasLength(2));
  });

  test('a broken upload is retried into the same attachment', () async {
    acceptUploads();
    supabase.on(
      'POST',
      '/storage/v1/object/photos/c1/f1/a1.jpg',
      (_) => throw const SocketException('lost'),
    );
    final photos = [photo('1.jpg')];

    final first = await repo.submitReport(
      projectId: 'p1',
      projectName: '',
      authorId: 'f1',
      authorName: '',
      text: '',
      photos: photos,
    );
    expect(first.failure.code, FailureCode.network);

    supabase
      ..on('POST', '/storage/v1/object/photos/c1/f1/a1.jpg', (_) => const FakeReply(200, {}))
      ..rpc('submit_report', _report());
    final second = await repo.submitReport(
      projectId: 'p1',
      projectName: '',
      authorId: 'f1',
      authorName: '',
      text: '',
      photos: photos,
    );

    expect(second.isSuccess, isTrue);
    expect(supabase.rpcCalls('create_upload'), hasLength(1));
  });

  test('a stranger attachment is forbidden', () async {
    acceptUploads();
    supabase.rpcFails('submit_report', 403, 'attachment_forbidden');

    final result = await repo.submitReport(
      projectId: 'p1',
      projectName: '',
      authorId: 'f1',
      authorName: '',
      text: '',
      photos: [photo('1.jpg')],
    );

    expect(result.failure.code, FailureCode.forbidden);
  });
}
