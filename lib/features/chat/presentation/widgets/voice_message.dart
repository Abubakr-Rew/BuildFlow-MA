import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_text_theme.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/audio/audio_providers.dart';
import 'package:buildflow/core/utils/date_formatter.dart';
import 'package:buildflow/core/widgets/voice_waveform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A voice note to play: the accent play button, the waveform (tap or
/// drag to seek), the time and, while it plays, the speed 1× / 1.5× / 2×.
/// Used in chat bubbles and for the recorded draft.
class VoiceNotePlayer extends ConsumerWidget {
  const VoiceNotePlayer({
    required this.playbackId,
    required this.url,
    required this.duration,
    required this.waveform,
    required this.playedColor,
    required this.color,
    required this.textColor,
    this.unheard = false,
    this.uploadProgress,
    this.onFirstPlay,
    super.key,
  });

  /// The note in `voicePlaybackProvider`: one plays at a time.
  final String playbackId;
  final String url;
  final Duration duration;
  final List<int> waveform;

  /// Bars already played, and the rest.
  final Color playedColor;
  final Color color;
  final Color textColor;

  /// Someone else's note the user hasn't played: a dot by the time.
  final bool unheard;

  /// While the note is being sent: its upload (0–1), `null` when not sending.
  final double? uploadProgress;

  /// Called when playback starts, e.g. to mark the note listened.
  final VoidCallback? onFirstPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.bfTheme;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final playback = ref.watch(voicePlaybackProvider);
    final notifier = ref.read(voicePlaybackProvider.notifier);
    final active = playback.activeId == playbackId;
    final playing = playback.isPlaying(playbackId);
    final position = playback.positionOf(playbackId);
    final total = duration.inMilliseconds;
    final progress = total == 0 ? 0.0 : position.inMilliseconds / total;

    void play() {
      if (!playing) onFirstPlay?.call();
      notifier.toggle(playbackId, url);
    }

    final timeStyle = theme.textTheme.labelSmall?.copyWith(
      color: textColor,
      fontWeight: FontWeight.w600,
      fontFeatures: AppTextTheme.tabular,
    );

    return Row(
      children: [
        _PlayButton(
          playing: playing,
          uploadProgress: uploadProgress,
          onPressed: play,
        ),
        const SizedBox(width: AppTheme.spacing8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              VoiceWaveform(
                bars: waveform,
                progress: progress,
                playedColor: playedColor,
                color: color,
                semanticsLabel: l10n.voiceMessage,
                onSeek: (fraction) {
                  if (!active) onFirstPlay?.call();
                  notifier.seek(
                    playbackId,
                    url,
                    Duration(milliseconds: (total * fraction).round()),
                  );
                },
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    DateFormatter.duration(active ? position : duration),
                    style: timeStyle,
                  ),
                  if (unheard) ...[
                    const SizedBox(width: AppTheme.spacing4),
                    Semantics(
                      label: l10n.voiceUnheard,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: t.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (active)
                    _SpeedButton(
                      speed: playback.speed,
                      color: textColor,
                      onPressed: notifier.cycleSpeed,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.uploadProgress,
    required this.onPressed,
  });

  static const _size = 40.0;

  final bool playing;
  final double? uploadProgress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    final l10n = AppLocalizations.of(context);
    final progress = uploadProgress;
    return SizedBox.square(
      dimension: _size + 6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (progress != null && progress < 1)
            SizedBox.square(
              dimension: _size + 6,
              child: CircularProgressIndicator(
                value: progress == 0 ? null : progress,
                strokeWidth: 2.5,
                color: t.accent,
                semanticsLabel: l10n.voiceUploading,
              ),
            ),
          SizedBox.square(
            dimension: _size,
            child: Material(
              color: t.accent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: t.onAccent,
                  semanticLabel: playing ? l10n.voicePause : l10n.voicePlay,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({
    required this.speed,
    required this.color,
    required this.onPressed,
  });

  final double speed;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).voiceSpeed(
      speed == speed.roundToDouble() ? speed.toStringAsFixed(0) : '$speed',
    );
    return Material(
      color: color.withValues(alpha: 0.14),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontFeatures: AppTextTheme.tabular,
                ),
          ),
        ),
      ),
    );
  }
}
