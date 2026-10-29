import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_text_theme.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/audio/voice_note.dart';
import 'package:buildflow/core/utils/date_formatter.dart';
import 'package:buildflow/core/widgets/voice_waveform.dart';
import 'package:buildflow/features/chat/presentation/providers/voice_recording_provider.dart';
import 'package:buildflow/features/chat/presentation/widgets/voice_message.dart';
import 'package:flutter/material.dart';

/// The microphone right of the empty message field: hold to record, lift
/// to send, swipe left to cancel, swipe up to lock. The pointer is
/// followed here, so the button must stay in the tree while held.
class VoiceMicButton extends StatefulWidget {
  const VoiceMicButton({
    required this.holding,
    required this.onPress,
    required this.onDrag,
    required this.onRelease,
    required this.onCancel,
    super.key,
  });

  final bool holding;
  final VoidCallback onPress;

  /// How far the finger moved from where it pressed.
  final ValueChanged<Offset> onDrag;
  final VoidCallback onRelease;
  final VoidCallback onCancel;

  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<VoiceMicButton> {
  Offset? _start;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: AppTheme.spacing8),
      child: Listener(
        onPointerDown: (e) {
          _start = e.position;
          widget.onPress();
        },
        onPointerMove: (e) {
          final start = _start;
          if (start != null) widget.onDrag(e.position - start);
        },
        onPointerUp: (_) {
          _start = null;
          widget.onRelease();
        },
        onPointerCancel: (_) {
          _start = null;
          widget.onCancel();
        },
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (widget.holding)
              Positioned(
                bottom: AppTheme.iconButtonSize + AppTheme.spacing16,
                child: _LockHint(label: l10n.voiceSlideToLock),
              ),
            AnimatedScale(
              scale: widget.holding ? 1.3 : 1,
              duration: const Duration(milliseconds: 120),
              child: SizedBox.square(
                dimension: AppTheme.iconButtonSize,
                child: Material(
                  color: t.accent,
                  shape: const CircleBorder(),
                  child: Tooltip(
                    message: l10n.recordVoice,
                    child: Icon(Icons.mic_rounded, color: t.onAccent),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockHint extends StatelessWidget {
  const _LockHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
        width: 36,
        decoration: ShapeDecoration(
          color: t.card,
          shape: StadiumBorder(side: BorderSide(color: t.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 18, color: t.textSecondary),
            Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 18,
              color: t.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// The red dot that blinks while recording, and the time.
class _RecordingTime extends StatefulWidget {
  const _RecordingTime({required this.elapsed});

  final Duration elapsed;

  @override
  State<_RecordingTime> createState() => _RecordingTimeState();
}

class _RecordingTimeState extends State<_RecordingTime>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0.2).animate(_blink),
          child: Semantics(
            label: AppLocalizations.of(context).voiceRecording,
            child: Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: t.danger.fg, shape: BoxShape.circle),
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacing8),
        Text(
          DateFormatter.duration(widget.elapsed),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: AppTextTheme.tabular,
              ),
        ),
      ],
    );
  }
}

/// The wave of the loudness so far, newest on the right.
class _LiveWave extends StatelessWidget {
  const _LiveWave({required this.levels});

  final List<double> levels;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    return VoiceWaveform(
      bars: [
        ...List.filled(voiceLiveBars - levels.length, 0),
        for (final level in levels) (level * 100).round(),
      ],
      progress: 1,
      height: 28,
      playedColor: t.textSecondary,
      color: t.textSecondary,
    );
  }
}

/// While the microphone is held: time, live wave, «Влево — отмена».
class VoiceHoldingBar extends StatelessWidget {
  const VoiceHoldingBar({required this.recording, super.key});

  final VoiceRecording recording;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    return SizedBox(
      height: AppTheme.iconButtonSize,
      child: Row(
        children: [
          const SizedBox(width: AppTheme.spacing8),
          _RecordingTime(elapsed: recording.elapsed),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(child: _LiveWave(levels: recording.levels)),
          const SizedBox(width: AppTheme.spacing12),
          Icon(Icons.chevron_left_rounded, size: 18, color: t.textTertiary),
          Text(
            AppLocalizations.of(context).voiceSlideToCancel,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// A locked recording: time and wave, then «Удалить», stop, «Отправить».
class VoiceLockedBar extends StatelessWidget {
  const VoiceLockedBar({
    required this.recording,
    required this.onDelete,
    required this.onStop,
    required this.onSend,
    super.key,
  });

  final VoiceRecording recording;
  final VoidCallback onDelete;
  final VoidCallback onStop;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const SizedBox(width: AppTheme.spacing8),
            _RecordingTime(elapsed: recording.elapsed),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(child: _LiveWave(levels: recording.levels)),
          ],
        ),
        const SizedBox(height: AppTheme.spacing8),
        _Actions(
          onDelete: onDelete,
          middle: IconButton(
            tooltip: l10n.voiceStop,
            onPressed: onStop,
            icon: const Icon(Icons.stop_circle_outlined),
            iconSize: 32,
          ),
          onSend: onSend,
        ),
      ],
    );
  }
}

/// A stopped recording waiting for the user: «Удалить», «Прослушать» with
/// the wave to seek, «Отправить». Never sent on its own.
class VoiceDraftBar extends StatelessWidget {
  const VoiceDraftBar({
    required this.note,
    required this.onDelete,
    required this.onSend,
    super.key,
  });

  final VoiceNote note;
  final VoidCallback onDelete;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    return _Actions(
      onDelete: onDelete,
      middle: Expanded(
        child: Semantics(
          label: AppLocalizations.of(context).voiceListen,
          child: VoiceNotePlayer(
            playbackId: VoiceRecordingNotifier.draftPlaybackId(note),
            url: note.path,
            duration: note.duration,
            waveform: note.waveform,
            playedColor: t.textPrimary,
            color: t.textTertiary.withValues(alpha: 0.45),
            textColor: t.textSecondary,
          ),
        ),
      ),
      onSend: onSend,
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.onDelete,
    required this.middle,
    required this.onSend,
  });

  final VoidCallback onDelete;
  final Widget middle;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: l10n.delete,
          onPressed: onDelete,
          icon: Icon(Icons.delete_outline_rounded, color: t.danger.fg),
        ),
        if (middle is Expanded) middle else ...[
          const Spacer(),
          middle,
          const Spacer(),
        ],
        const SizedBox(width: AppTheme.spacing8),
        Tooltip(
          message: l10n.sendMessage,
          child: SizedBox.square(
            dimension: AppTheme.iconButtonSize,
            child: Material(
              color: t.accent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onSend,
                child: Icon(Icons.arrow_upward_rounded, color: t.onAccent),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
