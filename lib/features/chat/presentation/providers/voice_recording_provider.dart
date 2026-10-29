import 'dart:async';
import 'dart:math';

import 'package:buildflow/core/audio/audio_providers.dart';
import 'package:buildflow/core/audio/voice_note.dart';
import 'package:buildflow/core/audio/voice_recorder.dart';
import 'package:buildflow/core/audio/waveform.dart';
import 'package:buildflow/core/config.dart';
import 'package:buildflow/core/photos/photo_compressor.dart';
import 'package:buildflow/core/photos/photo_providers.dart';
import 'package:buildflow/core/utils/haptics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where a voice recording is, WhatsApp style:
/// - [holding]: the finger is on the microphone; lifting it sends, a swipe
///   left cancels, a swipe up locks;
/// - [locked]: records without the finger, «Удалить» / stop / «Отправить»;
/// - [draft]: stopped (by the stop button, at [kVoiceMaxDuration] or by a
///   phone call) and waiting: «Удалить», «Прослушать», «Отправить». Nothing
///   is ever sent on its own.
enum VoicePhase {
  idle,

  /// Asking for the permission and starting the microphone.
  starting,
  holding,
  locked,
  draft;

  bool get isRecording => this == holding || this == locked;
}

/// One-off messages for a snack bar; [VoiceRecording.hintSeq] tells
/// repeats apart.
enum VoiceHint { tooShort, permissionDenied, failed }

@immutable
class VoiceRecording {
  const VoiceRecording({
    this.phase = VoicePhase.idle,
    this.elapsed = Duration.zero,
    this.levels = const [],
    this.draft,
    this.hint,
    this.hintSeq = 0,
  });

  final VoicePhase phase;
  final Duration elapsed;

  /// The latest loudness values (0–1), for the live wave.
  final List<double> levels;

  /// The stopped recording in [VoicePhase.draft].
  final VoiceNote? draft;
  final VoiceHint? hint;
  final int hintSeq;

  VoiceRecording copyWith({
    VoicePhase? phase,
    Duration? elapsed,
    List<double>? levels,
  }) =>
      VoiceRecording(
        phase: phase ?? this.phase,
        elapsed: elapsed ?? this.elapsed,
        levels: levels ?? this.levels,
        draft: draft,
        hint: hint,
        hintSeq: hintSeq,
      );
}

/// Swiping the finger this far left cancels the recording.
const voiceCancelDistance = 120.0;

/// Swiping it this far up locks it.
const voiceLockDistance = 80.0;

/// Loudness values the live wave shows.
const voiceLiveBars = 48;

/// The voice recording of a chat's message field, by chat id.
final voiceRecordingProvider = NotifierProvider.autoDispose
    .family<VoiceRecordingNotifier, VoiceRecording, String>(
  VoiceRecordingNotifier.new,
);

class VoiceRecordingNotifier
    extends AutoDisposeFamilyNotifier<VoiceRecording, String> {
  static const _tick = Duration(milliseconds: 100);

  late VoiceRecorder _recorder;

  /// Deletes files in the app cache only.
  late PhotoCompressor _files;
  Timer? _timer;
  StreamSubscription<double>? _levelsSub;
  StreamSubscription<void>? _interruptionsSub;
  final List<double> _levels = [];

  /// The finger came off while the permission dialog or the microphone
  /// was starting.
  bool _released = false;

  /// A stop is under way; the timer, a call and a button may race to it.
  bool _stopping = false;
  bool _disposed = false;

  /// Mirrors [state], which can't be read once disposed.
  VoiceRecording _current = const VoiceRecording();

  @override
  VoiceRecording build(String chatId) {
    _recorder = ref.watch(voiceRecorderProvider);
    _files = ref.watch(photoCompressorProvider);
    ref.onDispose(() {
      _disposed = true;
      _detach();
      // Leaving the chat drops an unfinished recording and its file.
      if (_current.phase.isRecording) unawaited(_recorder.cancel());
      if (_current.draft case final draft?) _deleteFile(draft.path);
    });
    return _current = const VoiceRecording();
  }

  void _set(VoiceRecording next) {
    if (!_disposed) state = _current = next;
  }

  void _hint(VoiceHint hint) => _set(
        VoiceRecording(hint: hint, hintSeq: state.hintSeq + 1),
      );

  void _idle() => _set(VoiceRecording(hintSeq: state.hintSeq));

  /// The finger touched the microphone: asks for the permission the first
  /// time, then records.
  Future<void> press() async {
    if (state.phase != VoicePhase.idle) return;
    _released = false;
    _set(VoiceRecording(phase: VoicePhase.starting, hintSeq: state.hintSeq));
    unawaited(ref.read(voicePlaybackProvider.notifier).stop());

    final bool granted;
    try {
      granted = await _recorder.hasPermission();
    } on Exception catch (e) {
      debugPrint('Microphone permission check failed: $e');
      _hint(VoiceHint.failed);
      return;
    }
    if (!granted) {
      _hint(VoiceHint.permissionDenied);
      return;
    }
    // The finger came off to answer the system dialog: the next press
    // records.
    if (_released) {
      _idle();
      return;
    }
    try {
      await _recorder.start();
    } on Exception catch (e) {
      debugPrint('Voice recording failed to start: $e');
      _hint(VoiceHint.failed);
      return;
    }
    if (_disposed) {
      unawaited(_recorder.cancel());
      return;
    }
    _levels.clear();
    _set(VoiceRecording(phase: VoicePhase.holding, hintSeq: state.hintSeq));
    unawaited(Haptics.medium());
    _levelsSub = _recorder.levels().listen((level) {
      _levels.add(level);
      _set(
        state.copyWith(
          levels: List.unmodifiable(
            _levels.sublist(max(0, _levels.length - voiceLiveBars)),
          ),
        ),
      );
    });
    // A phone call: what was said so far waits as a draft.
    _interruptionsSub = _recorder.interruptions().listen((_) => stop());
    _timer = Timer.periodic(_tick, (_) {
      final elapsed = state.elapsed + _tick;
      _set(state.copyWith(elapsed: elapsed));
      if (elapsed >= kVoiceMaxDuration) unawaited(stop());
    });
    // Lifted while the microphone was starting: as short as it gets.
    if (_released) await release();
  }

  /// The finger moved by [offset] from where it pressed.
  void drag(Offset offset) {
    if (state.phase != VoicePhase.holding) return;
    if (offset.dx <= -voiceCancelDistance) {
      unawaited(cancel());
    } else if (offset.dy <= -voiceLockDistance) {
      unawaited(Haptics.selection());
      _set(state.copyWith(phase: VoicePhase.locked));
    }
  }

  /// The finger came off. While holding, the note goes (returned to send),
  /// unless it is shorter than [kVoiceMinDuration].
  Future<VoiceNote?> release() async {
    switch (state.phase) {
      case VoicePhase.starting:
        _released = true;
        return null;
      case VoicePhase.holding when state.elapsed < kVoiceMinDuration:
        await _discard(VoiceHint.tooShort);
        return null;
      case VoicePhase.holding:
        final note = await _finish();
        if (note != null) _idle();
        return note;
      case VoicePhase.idle || VoicePhase.locked || VoicePhase.draft:
        return null;
    }
  }

  /// Drops the recording: the swipe left, «Удалить» while locked.
  Future<void> cancel() => _discard(null);

  /// Stops a recording into a draft: the stop button, the time limit, a
  /// phone call. A short vibration says it stopped.
  Future<void> stop() async {
    if (!state.phase.isRecording || _stopping) return;
    final elapsed = state.elapsed;
    final note = await _finish();
    if (note == null) return;
    if (elapsed < kVoiceMinDuration) {
      _deleteFile(note.path);
      _hint(VoiceHint.tooShort);
      return;
    }
    unawaited(Haptics.light());
    _set(
      VoiceRecording(
        phase: VoicePhase.draft,
        elapsed: elapsed,
        draft: note,
        hintSeq: state.hintSeq,
      ),
    );
  }

  /// «Отправить» while locked or in the draft: the note to send.
  Future<VoiceNote?> send() async {
    switch (state.phase) {
      case VoicePhase.locked when state.elapsed < kVoiceMinDuration:
        await _discard(VoiceHint.tooShort);
        return null;
      case VoicePhase.locked:
        final note = await _finish();
        if (note != null) _idle();
        return note;
      case VoicePhase.draft:
        final note = state.draft;
        await _stopDraftPlayback();
        _idle();
        return note;
      case VoicePhase.idle || VoicePhase.starting || VoicePhase.holding:
        return null;
    }
  }

  /// «Удалить» in the draft (or while locked).
  Future<void> delete() async {
    if (state.phase == VoicePhase.draft) {
      final draft = state.draft;
      await _stopDraftPlayback();
      if (draft != null) _deleteFile(draft.path);
      _idle();
      return;
    }
    await cancel();
  }

  /// The id the draft plays under in `voicePlaybackProvider`.
  static String draftPlaybackId(VoiceNote note) => 'draft:${note.path}';

  Future<void> _stopDraftPlayback() async {
    final draft = state.draft;
    final playback = ref.read(voicePlaybackProvider);
    if (draft != null && playback.activeId == draftPlaybackId(draft)) {
      await ref.read(voicePlaybackProvider.notifier).stop();
    }
  }

  Future<VoiceNote?> _finish() async {
    _stopping = true;
    final elapsed = state.elapsed;
    _detach();
    final String? path;
    try {
      path = await _recorder.stop();
    } on Exception catch (e) {
      debugPrint('Voice recording failed to stop: $e');
      _stopping = false;
      _hint(VoiceHint.failed);
      return null;
    }
    _stopping = false;
    if (path == null) {
      _hint(VoiceHint.failed);
      return null;
    }
    return VoiceNote(
      path: path,
      duration: elapsed,
      waveform: downsampleWaveform(_levels, kVoiceWaveformBars),
    );
  }

  Future<void> _discard(VoiceHint? hint) async {
    if (!state.phase.isRecording) return;
    _detach();
    try {
      await _recorder.cancel();
    } on Exception catch (e) {
      debugPrint('Voice recording failed to cancel: $e');
    }
    if (hint == null) {
      _idle();
    } else {
      _hint(hint);
    }
  }

  void _detach() {
    _timer?.cancel();
    _timer = null;
    unawaited(_levelsSub?.cancel());
    unawaited(_interruptionsSub?.cancel());
    _levelsSub = null;
    _interruptionsSub = null;
  }

  /// Files in the app cache only; the compressor's delete guards that.
  void _deleteFile(String path) => unawaited(_files.delete([path]));
}
