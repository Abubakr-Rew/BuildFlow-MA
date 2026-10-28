import 'package:buildflow/app/l10n/failure_messages.dart';
import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/routes.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/core/widgets/empty_state.dart';
import 'package:buildflow/core/widgets/error_state.dart';
import 'package:buildflow/core/widgets/loading_shimmer.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/presentation/providers/project_provider.dart';
import 'package:buildflow/features/projects/presentation/widgets/project_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Project list — all projects for a director, assigned ones otherwise.
class ProjectListScreen extends ConsumerWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final projects = ref.watch(projectsProvider);
    final isOwner = ref.watch(currentUserProvider)?.role.isOwner ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.projectsTitle),
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              heroTag: null, // shares the shell with the team tab's FAB
              onPressed: () => _showCreateSheet(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l10n.addProject),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(projectsProvider.future),
        child: projects.when(
          loading: () => const LoadingShimmerList(),
          error: (error, _) => ErrorState(
            message: l10n.failureMessage(error),
            onRetry: () => ref.invalidate(projectsProvider),
            retryLabel: l10n.retry,
          ),
          data: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.construction_outlined,
                title: l10n.noProjects,
                description:
                    isOwner ? l10n.noProjectsHint : l10n.noAssignedProjects,
                actionLabel: isOwner ? l10n.addProject : null,
                onAction:
                    isOwner ? () => _showCreateSheet(context, ref) : null,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                AppTheme.spacing16,
                AppTheme.spacing16,
                96, // keep the last card above the FAB
              ),
              itemCount: list.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppTheme.spacing12),
              itemBuilder: (context, index) =>
                  _ProjectCard(project: list[index]),
            );
          },
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateProjectSheet(),
    );
  }
}

class _CreateProjectSheet extends ConsumerStatefulWidget {
  const _CreateProjectSheet();

  @override
  ConsumerState<_CreateProjectSheet> createState() =>
      _CreateProjectSheetState();
}

class _CreateProjectSheetState extends ConsumerState<_CreateProjectSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(projectsProvider.notifier).createProject(
          name: _nameController.text,
          address: _addressController.text,
        );
    if (!mounted) return;
    setState(() => _saving = false);

    final message = result.when(
      success: (_) => l10n.projectSaved,
      failure: l10n.failureMessage,
    );
    messenger.showSnackBar(SnackBar(content: Text(message)));
    if (result.isSuccess) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.addProject, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppTheme.spacing24),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.projectName,
                hintText: l10n.projectNameHint,
                prefixIcon: const Icon(Icons.construction),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? l10n.validationProjectName
                  : null,
            ),
            const SizedBox(height: AppTheme.spacing16),
            TextFormField(
              controller: _addressController,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: l10n.projectAddress,
                hintText: l10n.projectAddressHint,
                prefixIcon: const Icon(Icons.location_on),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? l10n.validationProjectAddress
                  : null,
            ),
            const SizedBox(height: AppTheme.spacing24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.project(project.id)),
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
                  ProjectStatusBadge(status: project.status),
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
              const SizedBox(height: AppTheme.spacing8),
              Row(
                children: [
                  Icon(
                    Icons.engineering_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${l10n.foremenCount}: ${project.foremanIds.length}',
                    style: muted,
                  ),
                  const SizedBox(width: AppTheme.spacing16),
                  Icon(
                    Icons.handyman_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${l10n.workersCount}: ${project.workerIds.length}',
                    style: muted,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
