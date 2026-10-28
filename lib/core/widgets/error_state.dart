import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/widgets/bf_button.dart';
import 'package:flutter/material.dart';

/// Error state with icon, message, and retry button.
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.message,
    required this.onRetry,
    this.retryLabel,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  /// Defaults to [AppLocalizations.retry].
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.bfTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: t.danger.bg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: t.danger.fg,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: t.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing24),
            BfButton(
              label: retryLabel ?? AppLocalizations.of(context).retry,
              onPressed: onRetry,
              icon: Icons.refresh,
              variant: BfButtonVariant.outline,
            ),
          ],
        ),
      ),
    );
  }
}
