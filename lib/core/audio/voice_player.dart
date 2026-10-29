import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:buildflow/core/audio/demo_voice.dart';

/// The speaker, for voice messages. One for the whole app: playing a note
/// stops the one before (`VoicePlaybackNotifier`). Tests override
/// `voicePlayerProvider`.
abstract class VoicePlayer {
  /// Plays [url] (a local file, a `demo-voice:` note or, later, a link)
  /// from [from] at [speed].
  Future<void> play(String url, {required double speed, Duration from});
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);

  /// Position while playing.
  Stream<Duration> get positions;

  /// Fires when a note plays to its end.
  Stream<void> get completions;

  Future<void> dispose();
}

/// [VoicePlayer] over audioplayers (MediaPlayer on Android). It takes the
/// audio focus: a phone call pauses the note and the end of the call
/// resumes it.
class AudioplayersVoicePlayer implements VoicePlayer {
  AudioplayersVoicePlayer() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> play(
    String url, {
    required double speed,
    Duration from = Duration.zero,
  }) async {
    final source = switch (url) {
      _ when DemoVoice.isDemo(url) =>
        BytesSource(DemoVoice.wav(url), mimeType: 'audio/wav'),
      _ when url.startsWith('http') => UrlSource(url),
      _ => DeviceFileSource(url),
    };
    await _player.setPlaybackRate(speed);
    await _player.play(source, position: from);
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setPlaybackRate(speed);

  @override
  Stream<Duration> get positions => _player.onPositionChanged;

  @override
  Stream<void> get completions => _player.onPlayerComplete;

  @override
  Future<void> dispose() => _player.dispose();
}
