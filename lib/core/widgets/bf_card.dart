import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

/// Reusable card with consistent styling, optional photo thumbnail.
class BfCard extends StatelessWidget {
  const BfCard({
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final radius = context.bfTheme.cardBorderRadius;
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}
