import 'dart:async';

import 'package:buildflow/core/audio/audio_providers.dart';
import 'package:buildflow/core/config.dart';
import 'package:buildflow/core/photos/photo_providers.dart';
import 'package:buildflow/features/chat/presentation/providers/voice_recording_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_photo_compressor.dart';
import '../../../../helpers/fake_voice.dart';

/// The recording state machine. `testWidgets` for its fake clock: the
/// recording time is the 100 ms timer.
void main() {
  late FakeVoiceRecorder recorder;
  late FakeVoicePlayer player;
  late FakePhotoCompressor files;
  late ProviderContainer container;
  const chat = 'chat-project-1';

  void setUpContainer() {
    recorder = FakeVoiceRecorder();
    player = FakeVoicePlayer();
    files = FakePhotoCompressor();
    container = ProviderContainer(
      overrides: [
        voiceRecorderProvider.overrideWithValue(recorder),
        voicePlayerProvider.overrideWithValue(player),
        photoCompressorProvider.overrideWithValue(files),
      ],
    );
    addTearDown(container.dispose);
    container.listen(voiceRecordingProvider(chat), (_, __) {});
  }

  VoiceRecordingNotifier notifier() =>
      container.read(voiceRecordingProvider(chat).notifier);
  VoiceRecording state() => container.read(voiceRecordingProvider(chat));

  /// Presses and records for [duration], feeding a level every tick.
  Future<void> hold(WidgetTester tester, Duration duration) async {
    await notifier().press();
    for (var t = Duration.zero; t < duration; t += kTick) {
      recorder.emitLevel((t.inMilliseconds % 1000) / 1000);
      await tester.pump(kTick);
    }
  }

  testWidgets('hold and release sends the note with its length and waveform',
      (tester) async {
    setUpContainer();
    await hold(tester, const Duration(seconds: 3));
    expect(state().phase, VoicePhase.holding);
    expect(state().elapsed, const Duration(seconds: 3));
    expect(state().levels, isNotEmpty);

    final note = await notifier().release();
    expect(note, isNotNull);
    expect(note!.duration, const Duration(seconds: 3));
    expect(note.waveform, hasLength(kVoiceWaveformBars));
    expect(note.path, '/cache/voice-1.m4a');
    expect(state().phase, VoicePhase.idle);
    expect(recorder.calls, ['permission', 'start', 'stop']);
  });

  testWidgets('shorter than a second: «Удерживайте, чтобы записать»',
      (tester) async {
    setUpContainer();
    await hold(tester, const Duration(milliseconds: 600));
    expect(await notifier().release(), isNull);
    expect(state().phase, VoicePhase.idle);
    expect(state().hint, VoiceHint.tooShort);
    expect(recorder.calls.last, 'cancel');
  });

  testWidgets('a swipe left cancels; a small one does nothing',
      (tester) async {
    setUpContainer();
    await hold(tester, const Duration(seconds: 2));
    notifier().drag(const Offset(-60, 0));
    expect(state().phase, VoicePhase.holding);
    notifier().drag(const Offset(-130, 5));
    await tester.pump();
    expect(state().phase, VoicePhase.idle);
    expect(state().hint, isNull);
    expect(recorder.calls.last, 'cancel');
    expect(await notifier().release(), isNull);
  });

  testWidgets('a swipe up locks: lifting the finger sends nothing',
      (tester) async {
    setUpContainer();
    await hold(tester, const Duration(seconds: 2));
    notifier().drag(const Offset(0, -90));
    expect(state().phase, VoicePhase.locked);
    expect(await notifier().release(), isNull);

    await tester.pump(const Duration(seconds: 2));
    expect(state().elapsed, const Duration(seconds: 4));
    final note = await notifier().send();
    expect(note!.duration, const Duration(seconds: 4));
    expect(state().phase, VoicePhase.idle);
  });

  testWidgets('locked, then stopped: a draft to listen, send or delete',
      (tester) async {
    setUpContainer();
    await hold(tester, const Duration(seconds: 2));
    notifier().drag(const Offset(0, -90));
    await notifier().stop();
    expect(state().phase, VoicePhase.draft);
    final draft = state().draft!;

    // Time doesn't run in the draft.
    await tester.pump(const Duration(seconds: 2));
    expect(state().elapsed, const Duration(seconds: 2));

    // Listening to the draft, then sending it, stops the playback.
    await container
        .read(voicePlaybackProvider.notifier)
        .toggle(VoiceRecordingNotifier.draftPlaybackId(draft), draft.path);
    expect(await notifier().send(), draft);
    expect(container.read(voicePlaybackProvider).activeId, isNull);
    expect(state().phase, VoicePhase.idle);
  });

  testWidgets('deleting a draft deletes its file', (tester) async {
    setUpContainer();
    await hold(tester, const Duration(seconds: 2));
    notifier().drag(const Offset(0, -90));
    await notifier().stop();
    await notifier().delete();
    expect(state().phase, VoicePhase.idle);
    expect(files.deleted, ['/cache/voice-1.m4a']);
  });

  testWidgets('five minutes stop into a draft, even while held; not sent',
      (tester) async {
    setUpContainer();
    await notifier().press();
    await tester.pump(kVoiceMaxDuration);
    await tester.pump();
    expect(state().phase, VoicePhase.draft);
    expect(state().draft!.duration, kVoiceMaxDuration);
    // The finger comes off later: still a draft, nothing goes.
    expect(await notifier().release(), isNull);
    expect(state().phase, VoicePhase.draft);
  });

  testWidgets('a phone call keeps what was said as a draft', (tester) async {
    setUpContainer();
    await hold(tester, const Duration(seconds: 5));
    recorder.interrupt();
    await tester.pump();
    expect(state().phase, VoicePhase.draft);
    expect(state().draft!.duration, const Duration(seconds: 5));
    expect(recorder.calls.last, 'stop');
  });

  testWidgets('a refused permission says so and records nothing',
      (tester) async {
    setUpContainer();
    recorder.permitted = false;
    await notifier().press();
    expect(state().phase, VoicePhase.idle);
    expect(state().hint, VoiceHint.permissionDenied);
    expect(recorder.calls, ['permission']);

    // The same hint again is a new one for the snack bar.
    final seq = state().hintSeq;
    await notifier().press();
    expect(state().hintSeq, seq + 1);
  });

  testWidgets('the finger lifted for the permission dialog: no recording yet',
      (tester) async {
    setUpContainer();
    recorder.permissionDialog = Completer<bool>();
    final pressing = notifier().press();
    expect(state().phase, VoicePhase.starting);
    expect(await notifier().release(), isNull);
    recorder.permissionDialog!.complete(true);
    await pressing;
    expect(state().phase, VoicePhase.idle);
    expect(state().hint, isNull);
    expect(recorder.calls, ['permission']);
  });

  testWidgets('recording stops the voice note playing', (tester) async {
    setUpContainer();
    await container.read(voicePlaybackProvider.notifier).toggle('m-1', '/a.m4a');
    await notifier().press();
    expect(container.read(voicePlaybackProvider).activeId, isNull);
    expect(player.calls.last, 'stop');
    await notifier().cancel();
  });

  testWidgets('a microphone that fails to start says so', (tester) async {
    setUpContainer();
    recorder.startError = Exception('busy');
    await notifier().press();
    expect(state().hint, VoiceHint.failed);
    expect(state().phase, VoicePhase.idle);
  });

  testWidgets('leaving the chat drops the recording or the draft',
      (tester) async {
    setUpContainer();
    final sub = container.listen(voiceRecordingProvider('other'), (_, __) {});
    final other = container.read(voiceRecordingProvider('other').notifier);
    await other.press();
    sub.close();
    // Riverpod disposes an unwatched autoDispose provider a moment later.
    await tester.pump(const Duration(milliseconds: 10));
    expect(recorder.calls.last, 'cancel');
  });
}

const kTick = Duration(milliseconds: 100);
