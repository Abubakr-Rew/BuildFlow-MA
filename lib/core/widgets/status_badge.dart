import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

/// Color tone of a [StatusBadge].
enum StatusTone {
  /// In progress, report sent.
  active,
  paused,

  /// Error, no report today.
  danger,
  finished,

  /// Accent fill — only for counters that need attention (unread, missing).
  accent,

  /// Muted fill, secondary text.
  neutral;

  ToneColors colors(BuildFlowThemeExtension t) => switch (this) {
        active => t.active,
        paused => t.paused,
        danger => t.danger,
        finished => t.finished,
        accent => ToneColors(fg: t.onAccent, bg: t.accent),
        neutral => ToneColors(fg: t.textSecondary, bg: t.muted),
      };
}

/// Fully rounded pill with a short label: statuses, roles, counters.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    required this.tone,
    this.icon,
    super.key,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = tone.colors(context.bfTheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(
        color: colors.bg,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: colors.fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: colors.fg),
            ),
          ),
        ],
      ),
    );
  }
}
