import 'dart:math';

import 'package:flutter/material.dart';

/// Bars of a voice note's loudness (0–100 each). The part before
/// [progress] (0–1) is drawn in [playedColor]. With [onSeek] a tap or a
/// drag on the bars moves the playback there.
class VoiceWaveform extends StatelessWidget {
  const VoiceWaveform({
    required this.bars,
    required this.playedColor,
    required this.color,
    this.progress = 0,
    this.height = 32,
    this.onSeek,
    this.semanticsLabel,
    super.key,
  });

  final List<int> bars;
  final double progress;
  final Color playedColor;
  final Color color;
  final double height;

  /// Gets the fraction 0–1 of the note.
  final ValueChanged<double>? onSeek;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final paint = CustomPaint(
      size: Size.fromHeight(height),
      painter: _WaveformPainter(
        bars: bars,
        progress: progress.clamp(0, 1),
        playedColor: playedColor,
        color: color,
      ),
    );
    final seek = onSeek;
    if (seek == null) {
      return Semantics(label: semanticsLabel, child: paint);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        void seekTo(double dx) =>
            seek((dx / constraints.maxWidth).clamp(0.0, 1.0));
        return Semantics(
          label: semanticsLabel,
          slider: true,
          value: '${(progress * 100).round()}%',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => seekTo(d.localPosition.dx),
            onHorizontalDragUpdate: (d) => seekTo(d.localPosition.dx),
            child: paint,
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.playedColor,
    required this.color,
  });

  final List<int> bars;
  final double progress;
  final Color playedColor;
  final Color color;

  static const _gapShare = 0.45;
  static const _minBar = 0.12;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final step = size.width / bars.length;
    final width = max(1.5, step * (1 - _gapShare));
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (final (i, bar) in bars.indexed) {
      final level = max(_minBar, bar / 100);
      final h = size.height * level;
      final x = i * step + step / 2;
      final played = (i + 0.5) / bars.length <= progress;
      paint
        ..color = played ? playedColor : color
        ..strokeWidth = width;
      canvas.drawLine(
        Offset(x, (size.height - h) / 2 + width / 2),
        Offset(x, (size.height + h) / 2 - width / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.bars != bars ||
      old.playedColor != playedColor ||
      old.color != color;
}
