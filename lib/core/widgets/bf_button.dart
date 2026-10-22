import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/core/utils/haptics.dart';
import 'package:flutter/material.dart';

/// Primary action button — 56dp tall, full width, haptic feedback.
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
    final theme = Theme.of(context);

    final Widget child = isLoading
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: variant == BfButtonVariant.primary
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.primary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: AppTheme.spacing8),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    void handlePress() {
      Haptics.medium();
      onPressed?.call();
    }

    return switch (variant) {
      BfButtonVariant.primary => FilledButton(
          onPressed: isLoading ? null : handlePress,
          child: child,
        ),
      BfButtonVariant.secondary => OutlinedButton(
          onPressed: isLoading ? null : handlePress,
          child: child,
        ),
      BfButtonVariant.text => TextButton(
          onPressed: isLoading ? null : handlePress,
          child: child,
        ),
    };
  }
}

enum BfButtonVariant { primary, secondary, text }
