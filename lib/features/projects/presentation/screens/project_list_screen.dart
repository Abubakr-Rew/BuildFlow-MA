import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/widgets/empty_state.dart';
import 'package:buildflow/core/widgets/error_state.dart';
import 'package:buildflow/core/widgets/loading_shimmer.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/domain/entities/project_status.dart';
import 'package:buildflow/features/projects/presentation/providers/project_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Project list screen for owner — shows all construction sites.
class ProjectListScreen extends ConsumerWidget {
  const ProjectListScreen({this.isOwner = true, super.key});

  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final projects = ref.watch(projectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.projectsTitle),
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l10n.addProject),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(projectsProvider.future),
        child: projects.when(
          loading: () => const LoadingShimmerList(),
          error: (error, _) => ErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(projectsProvider),
            retryLabel: l10n.retry,
          ),
          data: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.construction_outlined,
                title: l10n.noProjects,
                actionLabel: isOwner ? l10n.addProject : null,
                onAction: isOwner
                    ? () => _showCreateDialog(context, ref)
                    : null,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              itemCount: list.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppTheme.spacing12),
              itemBuilder: (context, index) => _ProjectCard(
                project: list[index],
                isOwner: isOwner,
              ),
            );
          },
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.addProject,
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: AppTheme.spacing24),
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.projectName,
                  prefixIcon: const Icon(Icons.construction),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l10n.required : null,
              ),
              const SizedBox(height: AppTheme.spacing16),
              TextFormField(
                controller: addressController,
                decoration: InputDecoration(
                  labelText: l10n.projectAddress,
                  prefixIcon: const Icon(Icons.location_on),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l10n.required : null,
              ),
              const SizedBox(height: AppTheme.spacing24),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final success = await ref
                      .read(projectsProvider.notifier)
                      .createProject(
                        name: nameController.text,
                        address: addressController.text,
                      );
                  if (success && ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.isOwner});

  final Project project;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = context.bfTheme;
    final l10n = AppLocalizations.of(context);

    final statusColor = switch (project.status) {
      ProjectStatus.active => ext.success,
      ProjectStatus.paused => ext.warning,
      ProjectStatus.finished => theme.colorScheme.outline,
    };

    final statusText = switch (project.status) {
      ProjectStatus.active => l10n.statusActive,
      ProjectStatus.paused => l10n.statusPaused,
      ProjectStatus.finished => l10n.statusFinished,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // Future: navigate to project detail
        },
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing8),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      project.address,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              if (project.foremanIds.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacing8),
                Row(
                  children: [
                    Icon(
                      Icons.person_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${l10n.foremenCount}: ${project.foremanIds.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
