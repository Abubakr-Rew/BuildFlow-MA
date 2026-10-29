import 'dart:typed_data';

import 'package:buildflow/core/audio/audio_providers.dart';
import 'package:buildflow/core/audio/demo_voice.dart';
import 'package:buildflow/core/audio/waveform.dart';
import 'package:buildflow/core/utils/date_formatter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_voice.dart';

void main() {
  group('waveform', () {
    test('levels: −50 dBFS and quieter is silence, 0 dBFS is full', () {
      expect(levelFromDbfs(-160), 0);
      expect(levelFromDbfs(-50), 0);
      expect(levelFromDbfs(-25), 0.5);
      expect(levelFromDbfs(0), 1);
      expect(levelFromDbfs(double.nan), 0);
    });

    test('40 bars, the loudest is 100', () {
      final levels = [for (var i = 0; i < 400; i++) (i % 100) / 200];
      final bars = downsampleWaveform(levels, 40);
      expect(bars, hasLength(40));
      expect(bars.reduce((a, b) => a > b ? a : b), 100);
      expect(bars.every((b) => b >= 0 && b <= 100), isTrue);
    });

    test('a short recording is stretched; silence stays flat', () {
      expect(downsampleWaveform([0.2, 0.4], 4), [50, 50, 100, 100]);
      expect(downsampleWaveform(const [], 3), [0, 0, 0]);
      expect(downsampleWaveform([0, 0, 0], 2), [0, 0]);
    });
  });

  group('demo voice', () {
    final url = DemoVoice.url(7, const Duration(seconds: 5));

    test('is a playable 8 kHz mono WAV of its length', () {
      final wav = DemoVoice.wav(url);
      final header = ByteData.sublistView(wav);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(header.getUint16(22, Endian.little), 1);
      expect(header.getUint32(24, Endian.little), 8000);
      expect(wav.length, 44 + 5 * 8000 * 2);
    });

    test('has a speech-like waveform, the same every time', () {
      final waveform = DemoVoice.waveform(url, 40);
      expect(waveform, hasLength(40));
      expect(waveform, contains(100));
      expect(waveform, contains(lessThan(20)), reason: 'pauses');
      expect(DemoVoice.waveform(url, 40), waveform);
      expect(DemoVoice.isDemo(url), isTrue);
      expect(DemoVoice.isDemo('/cache/voice-1.m4a'), isFalse);
    });
  });

  test('durations read 0:42, 4:59', () {
    expect(DateFormatter.duration(const Duration(milliseconds: 42400)), '0:42');
    expect(DateFormatter.duration(const Duration(minutes: 4, seconds: 59)),
        '4:59');
    expect(DateFormatter.duration(const Duration(minutes: 12, seconds: 5)),
        '12:05');
  });

  group('voice playback', () {
    late FakeVoicePlayer player;
    late ProviderContainer container;

    setUp(() {
      player = FakeVoicePlayer();
      container = ProviderContainer(
        overrides: [voicePlayerProvider.overrideWithValue(player)],
      );
      addTearDown(container.dispose);
    });

    VoicePlaybackNotifier notifier() =>
        container.read(voicePlaybackProvider.notifier);
    VoicePlayback state() => container.read(voicePlaybackProvider);

    test('only one note plays: starting another stops the first', () async {
      await notifier().toggle('a', '/a.m4a');
      expect(state().isPlaying('a'), isTrue);

      await notifier().toggle('b', '/b.m4a');
      expect(state().isPlaying('a'), isFalse);
      expect(state().isPlaying('b'), isTrue);
      expect(player.calls, ['play /a.m4a 1.0x 0', 'stop', 'play /b.m4a 1.0x 0']);
    });

    test('pause keeps the place; play goes on from it', () async {
      await notifier().toggle('a', '/a.m4a');
      player.emitPosition(const Duration(seconds: 3));
      await Future<void>.delayed(Duration.zero);
      await notifier().toggle('a', '/a.m4a');
      expect(state().playing, isFalse);
      expect(state().positionOf('a'), const Duration(seconds: 3));
      await notifier().toggle('a', '/a.m4a');
      expect(player.calls.last, 'play /a.m4a 1.0x 3000');
    });

    test('the end of a note resets it', () async {
      await notifier().toggle('a', '/a.m4a');
      player.complete();
      await Future<void>.delayed(Duration.zero);
      expect(state().playing, isFalse);
      expect(state().positionOf('a'), Duration.zero);
    });

    test('speed goes 1× → 1.5× → 2× → 1× and applies to the playing note',
        () async {
      await notifier().toggle('a', '/a.m4a');
      await notifier().cycleSpeed();
      await notifier().cycleSpeed();
      expect(state().speed, 2);
      await notifier().cycleSpeed();
      expect(state().speed, 1);
      expect(player.calls.skip(1), ['speed 1.5x', 'speed 2.0x', 'speed 1.0x']);
    });

    test('seeking another note starts it there', () async {
      await notifier().toggle('a', '/a.m4a');
      await notifier().seek('b', '/b.m4a', const Duration(seconds: 4));
      expect(state().isPlaying('b'), isTrue);
      expect(player.calls.last, 'play /b.m4a 1.0x 4000');
      await notifier().seek('b', '/b.m4a', const Duration(seconds: 1));
      expect(player.calls.last, 'seek 1000');
    });

    test('stop silences everything, e.g. for a recording', () async {
      await notifier().toggle('a', '/a.m4a');
      await notifier().stop();
      expect(state().activeId, isNull);
      expect(player.calls.last, 'stop');
    });
  });
}
