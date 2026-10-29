import 'dart:math';
import 'dart:typed_data';

import 'package:buildflow/core/audio/waveform.dart';

/// Demo voice notes of the fake chat history: speech-like sound made in
/// code, so the repository carries no audio files. A note is a url
/// `demo-voice:<seed>:<durationMs>`; the player turns it into a WAV with
/// [wav], the history gets its waveform from [waveform].
abstract final class DemoVoice {
  static const scheme = 'demo-voice:';
  static const _sampleRate = 8000;

  static String url(int seed, Duration duration) =>
      '$scheme$seed:${duration.inMilliseconds}';

  static bool isDemo(String url) => url.startsWith(scheme);

  static (int seed, int durationMs) _parse(String url) {
    final [seed, ms] = url.substring(scheme.length).split(':');
    return (int.parse(seed), int.parse(ms));
  }

  /// Loudness 0–1 of every 10 ms: syllables of 120–260 ms, short gaps
  /// between them and longer pauses between words.
  static List<double> _envelope(String url) {
    final (seed, ms) = _parse(url);
    final random = Random(seed);
    final frames = ms ~/ 10;
    final envelope = List<double>.filled(frames, 0);
    var at = 15 + random.nextInt(20);
    while (at < frames - 10) {
      final syllables = 2 + random.nextInt(4);
      for (var s = 0; s < syllables && at < frames - 10; s++) {
        final length = 12 + random.nextInt(14);
        final loudness = 0.45 + random.nextDouble() * 0.55;
        for (var i = 0; i < length && at + i < frames; i++) {
          envelope[at + i] = loudness * sin(pi * i / length);
        }
        at += length + 4 + random.nextInt(8);
      }
      at += 30 + random.nextInt(25);
    }
    return envelope;
  }

  /// The waveform of the note, as a recorded one would have.
  static List<int> waveform(String url, int bars) =>
      downsampleWaveform(_envelope(url), bars);

  /// The note as a 16-bit mono WAV: a voiced tone of 110–170 Hz with a
  /// few harmonics and a slight vibrato under the syllable envelope.
  static Uint8List wav(String url) {
    final (seed, _) = _parse(url);
    final envelope = _envelope(url);
    final pitch = 110 + Random(seed).nextInt(60);
    final count = envelope.length * _sampleRate ~/ 100;
    final data = ByteData(44 + count * 2);

    void text(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    text(0, 'RIFF');
    data.setUint32(4, 36 + count * 2, Endian.little);
    text(8, 'WAVE');
    text(12, 'fmt ');
    data
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little) // PCM
      ..setUint16(22, 1, Endian.little) // mono
      ..setUint32(24, _sampleRate, Endian.little)
      ..setUint32(28, _sampleRate * 2, Endian.little)
      ..setUint16(32, 2, Endian.little)
      ..setUint16(34, 16, Endian.little);
    text(36, 'data');
    data.setUint32(40, count * 2, Endian.little);

    var phase = 0.0;
    for (var i = 0; i < count; i++) {
      final t = i / _sampleRate;
      final frame = i * 100 ~/ _sampleRate;
      final f = pitch * (1 + 0.04 * sin(2 * pi * 5 * t));
      phase += 2 * pi * f / _sampleRate;
      final tone =
          0.6 * sin(phase) + 0.25 * sin(2 * phase) + 0.15 * sin(3 * phase);
      final sample = (envelope[frame] * tone * 0.8 * 32767).round();
      data.setInt16(44 + i * 2, sample.clamp(-32768, 32767), Endian.little);
    }
    return data.buffer.asUint8List();
  }
}
