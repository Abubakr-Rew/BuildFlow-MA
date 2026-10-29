import 'dart:math';

/// Loudness 0–1 of a level in dBFS as the recorder reports it (−160…0).
/// Speech sits roughly between −50 and 0 dBFS; quieter is silence.
double levelFromDbfs(double dbfs) {
  const floor = -50.0;
  if (dbfs.isNaN) return 0;
  return ((dbfs - floor) / -floor).clamp(0.0, 1.0);
}

/// [bars] values 0–100 for the waveform of a voice message, from the
/// [levels] (0–1) sampled while recording. Each bar is the loudest level of
/// its slice; the loudest bar is 100, so quiet recordings still show shape.
/// Fewer levels than bars are stretched.
List<int> downsampleWaveform(List<double> levels, int bars) {
  if (bars <= 0) return const [];
  if (levels.isEmpty) return List.filled(bars, 0);
  final peaks = [
    for (var i = 0; i < bars; i++)
      () {
        final from = (i * levels.length / bars).floor();
        final to = max(from + 1, ((i + 1) * levels.length / bars).floor());
        return levels.sublist(from, min(to, levels.length)).reduce(max);
      }(),
  ];
  final loudest = peaks.reduce(max);
  if (loudest <= 0) return List.filled(bars, 0);
  return [for (final p in peaks) (p / loudest * 100).round().clamp(0, 100)];
}
