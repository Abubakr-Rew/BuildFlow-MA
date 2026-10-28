import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/core/widgets/status_badge.dart';
import 'package:buildflow/features/projects/domain/entities/project_status.dart';
import 'package:flutter/material.dart';

/// Localized name of a [ProjectStatus].
String projectStatusLabel(AppLocalizations l10n, ProjectStatus status) =>
    switch (status) {
      ProjectStatus.active => l10n.statusActive,
      ProjectStatus.paused => l10n.statusPaused,
      ProjectStatus.finished => l10n.statusFinished,
    };

/// Badge tone of a [ProjectStatus].
StatusTone projectStatusTone(ProjectStatus status) => switch (status) {
      ProjectStatus.active => StatusTone.active,
      ProjectStatus.paused => StatusTone.paused,
      ProjectStatus.finished => StatusTone.finished,
    };

/// Colored pill showing the project status.
class ProjectStatusBadge extends StatelessWidget {
  const ProjectStatusBadge({required this.status, super.key});

  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      label: projectStatusLabel(AppLocalizations.of(context), status),
      tone: projectStatusTone(status),
    );
  }
}
