import 'package:buildflow/app/theme/app_text_theme.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/utils/haptics.dart';
import 'package:flutter/material.dart';

/// Full-width action button with haptic feedback.
///
/// - [BfButtonVariant.primary] — the screen's main action, accent fill;
///   one per screen, usually pinned at the bottom.
/// - [BfButtonVariant.secondary] — graphite fill, white text.
/// - [BfButtonVariant.outline] — white with a border, for quiet actions.
/// - [BfButtonVariant.text] — a link-like accent text button.
class BfButton extends StatelessWidget {
  const BfButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = BfButtonVariant.primary,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final BfButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;

    final (bg, fg) = switch (variant) {
      BfButtonVariant.primary => (t.accent, t.onAccent),
      BfButtonVariant.secondary => (t.graphite, t.onGraphite),
      BfButtonVariant.outline => (t.card, t.textPrimary),
      BfButtonVariant.text => (Colors.transparent, t.accentText),
    };

    final Widget child = isLoading
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22),
                const SizedBox(width: AppTheme.spacing8),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    void handlePress() {
      Haptics.medium();
      onPressed?.call();
    }

    final onTap = isLoading || onPressed == null ? null : handlePress;

    if (variant == BfButtonVariant.text) {
      return TextButton(onPressed: onTap, child: child);
    }

    final style = FilledButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      // Keep the fill while loading: the spinner is drawn in [fg].
      disabledBackgroundColor: isLoading ? bg : t.muted,
      disabledForegroundColor: isLoading ? fg : t.textTertiary,
      textStyle: AppTextTheme.button,
      side: variant == BfButtonVariant.outline
          ? BorderSide(color: t.border)
          : null,
    );
    return FilledButton(onPressed: onTap, style: style, child: child);
  }
}

enum BfButtonVariant { primary, secondary, outline, text }
