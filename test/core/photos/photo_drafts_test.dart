import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/photos/photo_draft.dart';
import 'package:buildflow/core/photos/photo_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_photo_compressor.dart';

void main() {
  late FakePhotoCompressor compressor;
  late ProviderContainer container;
  const scope = 'report:test';

  setUp(() {
    compressor = FakePhotoCompressor();
    container = ProviderContainer(
      overrides: [photoCompressorProvider.overrideWithValue(compressor)],
    );
    addTearDown(container.dispose);
    // Keeps the autoDispose family alive for the test.
    container.listen(photoDraftsProvider(scope), (_, __) {});
  });

  PhotoDraftsNotifier notifier() =>
      container.read(photoDraftsProvider(scope).notifier);
  String stateOf(PhotoDraft d) => switch (d) {
        PhotoDraft(isReady: true) => 'ready',
        PhotoDraft(isFailed: true) => 'failed',
        _ => 'processing',
      };
  List<String> states() =>
      container.read(photoDraftsProvider(scope)).map(stateOf).toList();
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

  test('picked photos show at once and compress one by one', () async {
    notifier().add(['/c/1.jpg', '/c/2.jpg']);
    expect(states(), ['processing', 'processing']);
    expect(compressor.compressed, ['/c/1.jpg', '/c/2.jpg']);

    await settle();
    expect(states(), ['ready', 'ready']);
    final drafts = container.read(photoDraftsProvider(scope));
    expect(drafts.first.photo!.path, FakePhotoCompressor.copyOf('/c/1.jpg'));
    // The preview stays the original until the photo is sent.
    expect(drafts.first.sourcePath, '/c/1.jpg');
  });

  test('a failed compression keeps the photo to retry, not lose it', () async {
    compressor.failing.add('/c/bad.heic');
    notifier().add(['/c/bad.heic']);
    await settle();

    final failed = container.read(photoDraftsProvider(scope)).single;
    expect(failed.isFailed, isTrue);
    expect(failed.failure!.code, FailureCode.photoProcessing);
    expect(failed.sourcePath, '/c/bad.heic');
    expect(compressor.deleted, isEmpty);

    compressor.failing.clear();
    notifier().retry(failed.id);
    expect(states(), ['processing']);
    await settle();
    expect(states(), ['ready']);
    expect(compressor.compressed, ['/c/bad.heic', '/c/bad.heic']);
  });

  test('whenReady waits for every photo, in order', () async {
    notifier().add(['/c/1.jpg', '/c/2.jpg']);
    final ready = await notifier().whenReady();
    expect(ready.value.map((p) => p.path), [
      FakePhotoCompressor.copyOf('/c/1.jpg'),
      FakePhotoCompressor.copyOf('/c/2.jpg'),
    ]);
  });

  test('whenReady reports a failed photo', () async {
    compressor.failing.add('/c/2.jpg');
    notifier().add(['/c/1.jpg', '/c/2.jpg']);
    final ready = await notifier().whenReady();
    expect(ready, isA<Err<Object>>());
    expect(ready.failure.code, FailureCode.photoProcessing);
  });

  test('removing a photo deletes the original and the copy', () async {
    notifier().add(['/c/1.jpg']);
    await settle();
    notifier().remove(container.read(photoDraftsProvider(scope)).single.id);
    expect(container.read(photoDraftsProvider(scope)), isEmpty);
    expect(compressor.deleted, [
      '/c/1.jpg',
      FakePhotoCompressor.copyOf('/c/1.jpg'),
    ]);
  });

  test('a photo removed while compressing loses its copy on arrival',
      () async {
    notifier().add(['/c/1.jpg']);
    notifier().remove(container.read(photoDraftsProvider(scope)).single.id);
    expect(compressor.deleted, ['/c/1.jpg']);
    await settle();
    expect(compressor.deleted, [
      '/c/1.jpg',
      FakePhotoCompressor.copyOf('/c/1.jpg'),
    ]);
    expect(container.read(photoDraftsProvider(scope)), isEmpty);
  });

  test('takeAll hands photos over with their running compression', () async {
    notifier().add(['/c/1.jpg']);
    final handoffs = notifier().takeAll();
    expect(container.read(photoDraftsProvider(scope)), isEmpty);
    expect(handoffs.single.draft.sourcePath, '/c/1.jpg');

    final result = await handoffs.single.result;
    expect(result.value.path, FakePhotoCompressor.copyOf('/c/1.jpg'));
    // The receiver owns the files now.
    await settle();
    expect(compressor.deleted, isEmpty);
  });

  test('clear after sending deletes only the originals', () async {
    notifier().add(['/c/1.jpg']);
    await settle();
    notifier().clear();
    expect(compressor.deleted, ['/c/1.jpg']);
  });

  test('leaving the place deletes the photos still there', () async {
    final c = ProviderContainer(
      overrides: [photoCompressorProvider.overrideWithValue(compressor)],
    );
    final sub = c.listen(photoDraftsProvider('chat:1'), (_, __) {});
    c.read(photoDraftsProvider('chat:1').notifier).add(['/c/1.jpg']);
    await settle();
    sub.close();
    await settle();
    expect(compressor.deleted, [
      '/c/1.jpg',
      FakePhotoCompressor.copyOf('/c/1.jpg'),
    ]);
    c.dispose();
  });
}
