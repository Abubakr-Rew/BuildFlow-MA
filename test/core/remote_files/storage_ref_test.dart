import 'package:buildflow/core/remote_files/storage_ref.dart';
import 'package:buildflow/features/chat/domain/entities/message_attachment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a storage link names the bucket, the path and the attachment', () {
    final ref = StorageRef.tryParse('storage:voice/c1/u1/a-1.m4a')!;

    expect(ref.bucket, 'voice');
    expect(ref.path, 'c1/u1/a-1.m4a');
    expect(ref.attachmentId, 'a-1');
    expect(ref.extension, 'm4a');
    expect(ref.url, 'storage:voice/c1/u1/a-1.m4a');
  });

  test('other links are not storage links', () {
    for (final url in ['fake:1', '/data/x.jpg', 'https://x', 'storage:', 'storage:photos/']) {
      expect(StorageRef.tryParse(url), isNull, reason: url);
    }
  });

  test('an attachment from the server gets a storage url', () {
    final attachment = MessageAttachment.fromJson({
      'id': 'a1',
      'bucket': 'photos',
      'path': 'c1/u1/a1.jpg',
      'width': 1600,
      'height': 1200,
    });
    expect(attachment.url, 'storage:photos/c1/u1/a1.jpg');

    // The fake data and the JSON round trip keep their url.
    expect(MessageAttachment.fromJson(attachment.toJson()), attachment);
    expect(
      MessageAttachment.fromJson({'id': 'a', 'url': 'fake:1'}).url,
      'fake:1',
    );
  });
}
