import 'dart:io';

import 'package:buildflow/core/audio/audio_providers.dart';
import 'package:buildflow/core/remote_files/remote_files.dart';
import 'package:buildflow/core/remote_files/remote_files_providers.dart';
import 'package:buildflow/core/remote_files/storage_ref.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_voice.dart';

void main() {
  late Directory cache;
  late FakeVoicePlayer player;
  late RemoteFiles files;
  late ProviderContainer container;

  const note = StorageRef('voice', 'c1/u1/v1.m4a');

  setUp(() async {
    cache = await Directory.systemTemp.createTemp('voice_storage_test');
    player = FakeVoicePlayer();
    // No gateway: only files already on the phone can be had.
    files = RemoteFiles(cacheDir: () async => cache.path);
    container = ProviderContainer(
      overrides: [
        voicePlayerProvider.overrideWithValue(player),
        remoteFilesProvider.overrideWithValue(files),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await cache.delete(recursive: true);
  });

  test('a note in Storage plays from its downloaded file', () async {
    final recorded = File('${cache.path}/rec.m4a')..writeAsBytesSync([1]);
    await files.adopt(note, recorded.path);

    await container.read(voicePlaybackProvider.notifier).toggle('m1', note.url);

    expect(player.calls, ['play ${cache.path}/remote/v1.m4a 1.0x 0']);
    expect(container.read(voicePlaybackProvider).isPlaying('m1'), isTrue);
  });

  test("a note that can't be had stops instead of playing", () async {
    await container.read(voicePlaybackProvider.notifier).toggle('m1', note.url);

    expect(player.calls, isEmpty);
    expect(container.read(voicePlaybackProvider).playing, isFalse);
  });
}
