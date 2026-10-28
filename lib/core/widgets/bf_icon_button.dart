import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

/// Square 44×44 icon button, radius 14.
///
/// [translucent] is for buttons laid over a dark header or a photo:
/// translucent white without a border.
class BfIconButton extends StatelessWidget {
  const BfIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.translucent = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool translucent;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    return Tooltip(
      message: tooltip,
      child: BfIconButtonSurface(
        translucent: translucent,
        onTap: onPressed,
        child: Icon(
          icon,
          size: 22,
          // The translucent surface is white in both themes.
          color: translucent ? t.onAccent : t.textPrimary,
        ),
      ),
    );
  }
}

/// The 44×44 surface of [BfIconButton], for wrapping other tappables
/// (e.g. a `PopupMenuButton` icon).
class BfIconButtonSurface extends StatelessWidget {
  const BfIconButtonSurface({
    required this.child,
    this.translucent = false,
    this.onTap,
    super.key,
  });

  final Widget child;
  final bool translucent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    return SizedBox.square(
      dimension: AppTheme.iconButtonSize,
      child: Material(
        color: translucent ? t.onGraphite.withValues(alpha: 0.9) : t.card,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(BuildFlowThemeExtension.iconButtonRadius),
          side: translucent ? BorderSide.none : BorderSide(color: t.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Center(child: child)),
      ),
    );
  }
}
