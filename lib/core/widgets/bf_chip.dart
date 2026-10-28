import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

/// Fully rounded chip for filters and quick templates.
/// Selected: graphite with white text; otherwise a muted fill.
class BfChip extends StatelessWidget {
  const BfChip({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    final fg = selected ? t.onGraphite : t.textPrimary;
    return Semantics(
      selected: selected,
      button: true,
      child: ConstrainedBox(
        // The visible pill is 36 tall; the tap area reaches the minimum.
        constraints: const BoxConstraints(minHeight: AppTheme.minTouchTarget),
        child: Center(
          widthFactor: 1,
          child: Material(
            color: selected ? t.graphite : t.muted,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: fg),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: fg),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
