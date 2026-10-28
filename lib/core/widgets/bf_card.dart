import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

/// Flat card: 1px border, radius 20, no shadow.
class BfCard extends StatelessWidget {
  const BfCard({
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.color,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  /// Fill instead of the card color, e.g. `context.bfTheme.graphite`.
  /// A filled card has no border.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    final radius = BorderRadius.circular(BuildFlowThemeExtension.cardRadius);
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: color ?? t.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: color == null ? BorderSide(color: t.border) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppTheme.spacing16),
            child: child,
          ),
        ),
      ),
    );
  }
}
