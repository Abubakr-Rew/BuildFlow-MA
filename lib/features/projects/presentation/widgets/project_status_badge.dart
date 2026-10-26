import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/features/projects/domain/entities/project_status.dart';
import 'package:flutter/material.dart';

/// Localized name of a [ProjectStatus].
String projectStatusLabel(AppLocalizations l10n, ProjectStatus status) =>
    switch (status) {
      ProjectStatus.active => l10n.statusActive,
      ProjectStatus.paused => l10n.statusPaused,
      ProjectStatus.finished => l10n.statusFinished,
    };

/// Colored pill showing the project status.
class ProjectStatusBadge extends StatelessWidget {
  const ProjectStatusBadge({required this.status, super.key});

  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = context.bfTheme;

    final color = switch (status) {
      ProjectStatus.active => ext.success,
      ProjectStatus.paused => ext.warning,
      ProjectStatus.finished => theme.colorScheme.outline,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        projectStatusLabel(AppLocalizations.of(context), status),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
