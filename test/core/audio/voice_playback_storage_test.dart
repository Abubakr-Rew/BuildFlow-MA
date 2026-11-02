import 'dart:async';
import 'dart:io';

import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/core/audio/audio_providers.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/remote_files/remote_files.dart';
import 'package:buildflow/core/remote_files/remote_files_providers.dart';
import 'package:buildflow/core/remote_files/storage_ref.dart';
import 'package:buildflow/features/chat/presentation/widgets/voice_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_voice.dart';
import '../../helpers/test_app.dart';

/// Downloads that finish when the test says so.
class _SlowFiles extends RemoteFiles {
  _SlowFiles(this.path) : super(cacheDir: () async => '');

  final String path;
  final done = Completer<void>();

  @override
  Future<Result<String>> localPath(StorageRef ref) async {
    await done.future;
    return Success(path);
  }
}

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

  group('while the file downloads', () {
    late _SlowFiles slow;

    setUp(() {
      slow = _SlowFiles('/cache/remote/v1.m4a');
      container = ProviderContainer(
        overrides: [
          voicePlayerProvider.overrideWithValue(player),
          remoteFilesProvider.overrideWithValue(slow),
        ],
      );
    });

    test('the note is loading, then plays', () async {
      final playing = container
          .read(voicePlaybackProvider.notifier)
          .toggle('m1', note.url);
      await pumpEventQueue();
      expect(container.read(voicePlaybackProvider).isLoading('m1'), isTrue);
      expect(player.calls, isEmpty);

      slow.done.complete();
      await playing;

      expect(container.read(voicePlaybackProvider).isLoading('m1'), isFalse);
      expect(player.calls, ['play /cache/remote/v1.m4a 1.0x 0']);
    });

    test('a tap while it loads cancels: nothing plays', () async {
      final notifier = container.read(voicePlaybackProvider.notifier);
      final first = notifier.toggle('m1', note.url);
      await pumpEventQueue();

      await notifier.toggle('m1', note.url);
      slow.done.complete();
      await first;

      final state = container.read(voicePlaybackProvider);
      expect(state.isLoading('m1'), isFalse);
      expect(state.playing, isFalse);
      expect(player.calls.where((c) => c.startsWith('play')), isEmpty);
    });

    testWidgets('the play button spins', (tester) async {
      // Made here: a future of setUp completes outside the fake time.
      slow = _SlowFiles('/cache/remote/v1.m4a');
      await pumpTestApp(
        tester,
        Scaffold(
          body: VoiceNotePlayer(
            playbackId: 'm1',
            url: note.url,
            duration: const Duration(seconds: 7),
            waveform: List.filled(40, 50),
            playedColor: Colors.black,
            color: Colors.grey,
            textColor: Colors.black,
          ),
        ),
        overrides: [
          voicePlayerProvider.overrideWithValue(player),
          remoteFilesProvider.overrideWithValue(slow),
        ],
      );
      final ring = find.bySemanticsLabel(AppLocalizationsRu().voiceDownloading);
      expect(ring, findsNothing);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(ring, findsOneWidget);

      slow.done.complete();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(ring, findsNothing);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });
  });
}
