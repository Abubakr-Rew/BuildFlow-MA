import 'package:buildflow/core/audio/waveform.dart';
import 'package:buildflow/core/config.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// The microphone, for voice messages. Throws what the platform throws;
/// `VoiceRecordingNotifier` turns it into a hint. Tests override
/// `voiceRecorderProvider`.
abstract class VoiceRecorder {
  /// Whether the app may record; with [request] the system asks the user
  /// the first time.
  Future<bool> hasPermission({bool request = true});

  /// Starts a new note in the app cache.
  Future<void> start();

  /// Stops and returns the file, or `null` if nothing was recorded.
  Future<String?> stop();

  /// Stops and deletes the file.
  Future<void> cancel();

  /// Loudness 0–1 about every 100 ms while recording.
  Stream<double> levels();

  /// Fires when the system pauses the recording, e.g. for a phone call.
  Stream<void> interruptions();
}

/// [VoiceRecorder] over package:record: AAC-LC in M4A, mono, at
/// [kVoiceBitRate]; a call pauses the recording.
class RecordVoiceRecorder implements VoiceRecorder {
  RecordVoiceRecorder() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  static const _paths = MethodChannel('buildflow/paths');
  static const _uuid = Uuid();

  @override
  Future<bool> hasPermission({bool request = true}) =>
      _recorder.hasPermission(request: request);

  @override
  Future<void> start() async {
    final cache = await _paths.invokeMethod<String>('cacheDir');
    await _recorder.start(
      // The defaults: AAC-LC in M4A, and a phone call pauses the recording
      // (AudioInterruptionMode.pause), which [interruptions] reports.
      const RecordConfig(
        bitRate: kVoiceBitRate,
        sampleRate: kVoiceSampleRate,
        numChannels: 1,
      ),
      path: '$cache/voice-${_uuid.v4()}.m4a',
    );
  }

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Stream<double> levels() => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      .map((a) => levelFromDbfs(a.current));

  @override
  Stream<void> interruptions() =>
      _recorder.onStateChanged().where((s) => s == RecordState.pause);
}
