import 'dart:async';

import 'package:buildflow/core/audio/voice_player.dart';
import 'package:buildflow/core/audio/voice_recorder.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/remote_files/remote_files_providers.dart';
import 'package:buildflow/core/remote_files/storage_ref.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The microphone; tests override it.
final voiceRecorderProvider = Provider<VoiceRecorder>(
  (ref) => RecordVoiceRecorder(),
);

/// The one speaker of the app; tests override it.
final voicePlayerProvider = Provider<VoicePlayer>((ref) {
  final player = AudioplayersVoicePlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// What the speaker plays: at most one voice note in the app at a time.
@immutable
class VoicePlayback {
  const VoicePlayback({
    this.activeId,
    this.playing = false,
    this.position = Duration.zero,
    this.speed = 1,
  });

  /// The note last started; it keeps its position while paused.
  final String? activeId;
  final bool playing;
  final Duration position;

  /// 1×, 1.5× or 2×, for every note until the app closes.
  final double speed;

  bool isPlaying(String id) => playing && activeId == id;

  /// Where note [id] stands: its position if it's the active one.
  Duration positionOf(String id) =>
      activeId == id ? position : Duration.zero;

  VoicePlayback copyWith({
    String? activeId,
    bool? playing,
    Duration? position,
    double? speed,
  }) =>
      VoicePlayback(
        activeId: activeId ?? this.activeId,
        playing: playing ?? this.playing,
        position: position ?? this.position,
        speed: speed ?? this.speed,
      );
}

/// Speeds the speed button goes through.
const voiceSpeeds = [1.0, 1.5, 2.0];

final voicePlaybackProvider =
    NotifierProvider<VoicePlaybackNotifier, VoicePlayback>(
  VoicePlaybackNotifier.new,
);

class VoicePlaybackNotifier extends Notifier<VoicePlayback> {
  late VoicePlayer _player;

  @override
  VoicePlayback build() {
    _player = ref.watch(voicePlayerProvider);
    final positions = _player.positions.listen((p) {
      if (state.activeId != null) state = state.copyWith(position: p);
    });
    final completions = _player.completions.listen(
      (_) => state = state.copyWith(playing: false, position: Duration.zero),
    );
    ref.onDispose(() {
      unawaited(positions.cancel());
      unawaited(completions.cancel());
    });
    return const VoicePlayback();
  }

  /// Plays or pauses note [id]; another note playing stops first.
  Future<void> toggle(String id, String url) async {
    if (state.activeId == id) {
      if (state.playing) {
        state = state.copyWith(playing: false);
        await _player.pause();
      } else {
        state = state.copyWith(playing: true);
        await _play(id, url, state.position);
      }
      return;
    }
    await _start(id, url, Duration.zero);
  }

  /// Moves note [id] to [position]; a note that isn't the active one
  /// starts playing there.
  Future<void> seek(String id, String url, Duration position) async {
    if (state.activeId == id) {
      state = state.copyWith(position: position);
      if (state.playing) {
        await _player.seek(position);
      } else {
        state = state.copyWith(playing: true);
        await _play(id, url, position);
      }
      return;
    }
    await _start(id, url, position);
  }

  Future<void> _start(String id, String url, Duration from) async {
    if (state.activeId != null) await _player.stop();
    state = VoicePlayback(
      activeId: id,
      playing: true,
      position: from,
      speed: state.speed,
    );
    await _play(id, url, from);
  }

  /// Plays note [id] from [from]. A note in Storage plays from its
  /// downloaded file; if it can't be had, the note stops. If the user
  /// paused or picked another note during the download, nothing plays.
  Future<void> _play(String id, String url, Duration from) async {
    var source = url;
    if (StorageRef.tryParse(url) case final storage?) {
      final file = await ref.read(remoteFilesProvider).localPath(storage);
      if (state.activeId != id || !state.playing) return;
      switch (file) {
        case Success(:final value):
          source = value;
        case Err():
          state = state.copyWith(playing: false);
          return;
      }
    }
    await _player.play(source, speed: state.speed, from: from);
  }

  /// 1× → 1.5× → 2× → 1×.
  Future<void> cycleSpeed() async {
    final next = voiceSpeeds[
        (voiceSpeeds.indexOf(state.speed) + 1) % voiceSpeeds.length];
    state = state.copyWith(speed: next);
    if (state.playing) await _player.setSpeed(next);
  }

  /// Stops whatever plays, e.g. when a recording starts.
  Future<void> stop() async {
    if (state.activeId == null) return;
    state = VoicePlayback(speed: state.speed);
    await _player.stop();
  }
}
