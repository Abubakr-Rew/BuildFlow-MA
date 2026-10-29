import 'package:flutter/foundation.dart';

/// A recorded voice note on the phone, ready to send: AAC in M4A.
@immutable
class VoiceNote {
  const VoiceNote({
    required this.path,
    required this.duration,
    required this.waveform,
  });

  static const mime = 'audio/mp4';

  final String path;
  final Duration duration;

  /// `kVoiceWaveformBars` values 0–100.
  final List<int> waveform;

  @override
  bool operator ==(Object other) =>
      other is VoiceNote &&
      other.path == path &&
      other.duration == duration &&
      listEquals(other.waveform, waveform);

  @override
  int get hashCode => Object.hash(path, duration, Object.hashAll(waveform));

  @override
  String toString() => 'VoiceNote($path, $duration)';
}
