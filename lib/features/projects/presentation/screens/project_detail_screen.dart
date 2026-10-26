import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/core/widgets/empty_state.dart';
import 'package:buildflow/core/widgets/error_state.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/role_label.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/domain/entities/project_status.dart';
import 'package:buildflow/features/projects/presentation/providers/project_provider.dart';
import 'package:buildflow/features/projects/presentation/widgets/project_status_badge.dart';
import 'package:buildflow/features/reports/presentation/providers/report_provider.dart';
import 'package:buildflow/features/reports/presentation/screens/new_report_screen.dart';
import 'package:buildflow/features/reports/presentation/widgets/report_card.dart';
import 'package:buildflow/features/team/domain/entities/member.dart';
import 'package:buildflow/features/team/presentation/providers/team_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Project page: info, team and reports.
///
/// Directors can change the status and the team; foremen can start a
/// report for this project.
class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final project = ref.watch(projectByIdProvider(projectId));
    final role = ref.watch(currentUserProvider)?.role;

    final loaded = project.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(loaded?.name ?? ''),
        actions: [
          if (role == UserRole.owner && loaded != null)
            PopupMenuButton<ProjectStatus>(
              tooltip: l10n.projectStatus,
              icon: const Icon(Icons.more_vert),
              onSelected: (status) =>
                  _changeStatus(context, ref, loaded, status),
              itemBuilder: (_) => [
                for (final status in ProjectStatus.values)
                  CheckedPopupMenuItem(
                    value: status,
                    checked: status == loaded.status,
                    child: Text(projectStatusLabel(l10n, status)),
                  ),
              ],
            ),
        ],
      ),
      floatingActionButton:
          role == UserRole.foreman && loaded != null && loaded.status.isActive
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          NewReportScreen(initialProjectId: loaded.id),
                    ),
                  ),
                  icon: const Icon(Icons.add_a_photo),
                  label: Text(l10n.newReport),
                )
              : null,
      body: project.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(projectsProvider),
          retryLabel: l10n.retry,
        ),
        data: (project) => project == null
            ? EmptyState(
                icon: Icons.construction_outlined,
                title: l10n.projectNotFound,
              )
            : _ProjectBody(project: project, isOwner: role == UserRole.owner),
      ),
    );
  }

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    Project project,
    ProjectStatus status,
  ) async {
    if (status == project.status) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok =
        await ref.read(projectsProvider.notifier).setStatus(project, status);
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? l10n.statusChanged : l10n.actionFailed)),
    );
  }
}

class _ProjectBody extends ConsumerWidget {
  const _ProjectBody({required this.project, required this.isOwner});

  final Project project;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final members = ref.watch(membersProvider).valueOrNull ?? const [];
    final reports = ref.watch(projectReportsProvider(project.id));

    List<Member> byIds(List<String> ids) =>
        members.where((m) => ids.contains(m.userId)).toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(projectsProvider)
          ..invalidate(membersProvider);
        await ref.read(reportsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing16,
          AppTheme.spacing16,
          AppTheme.spacing16,
          96, // keep content above the FAB
        ),
        children: [
          // Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          project.address,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                  Row(
                    children: [
                      Text(
                        '${l10n.projectStatus}: ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      ProjectStatusBadge(status: project.status),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),

          // Team
          Row(
            children: [
              Expanded(
                child: Text(l10n.projectTeam, style: theme.textTheme.titleMedium),
              ),
              if (isOwner)
                TextButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => _EditTeamSheet(project: project),
                  ),
                  icon: const Icon(Icons.edit, size: 18),
                  label: Text(l10n.editTeam),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing8),
          _TeamGroup(
            title: l10n.foremen,
            members: byIds(project.foremanIds),
          ),
          const SizedBox(height: AppTheme.spacing8),
          _TeamGroup(
            title: l10n.workers,
            members: byIds(project.workerIds),
          ),
          const SizedBox(height: AppTheme.spacing24),

          // Reports
          Text(l10n.projectReports, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppTheme.spacing8),
          ...reports.when(
            loading: () => const [
              Padding(
                padding: EdgeInsets.all(AppTheme.spacing24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (error, _) => [Text(error.toString())],
            data: (list) => list.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spacing16),
                      child: Text(
                        l10n.noReportsForProject,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ]
                : [
                    for (final report in list)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppTheme.spacing12),
                        child: ReportCard(report: report, showProject: false),
                      ),
                  ],
          ),
        ],
      ),
    );
  }
}

class _TeamGroup extends StatelessWidget {
  const _TeamGroup({required this.title, required this.members});

  final String title;
  final List<Member> members;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            if (members.isEmpty)
              Text(
                l10n.nobodyAssigned,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in members)
                    Chip(
                      avatar: Icon(
                        m.role.icon,
                        size: 18,
                        color: m.role.color(theme.colorScheme),
                      ),
                      label: Text(m.name),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Director's sheet for choosing which foremen and workers are on a project.
class _EditTeamSheet extends ConsumerStatefulWidget {
  const _EditTeamSheet({required this.project});

  final Project project;

  @override
  ConsumerState<_EditTeamSheet> createState() => _EditTeamSheetState();
}

class _EditTeamSheetState extends ConsumerState<_EditTeamSheet> {
  late final Set<String> _foremen = {...widget.project.foremanIds};
  late final Set<String> _workers = {...widget.project.workerIds};
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(projectsProvider.notifier).setTeam(
          widget.project,
          foremanIds: _foremen.toList(),
          workerIds: _workers.toList(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? l10n.teamSaved : l10n.actionFailed)),
    );
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final members = ref.watch(membersProvider).valueOrNull ?? const [];
    final foremen = members.where((m) => m.role.isForeman).toList();
    final workers = members.where((m) => m.role.isWorker).toList();

    Widget tile(Member m, Set<String> selected) => CheckboxListTile(
          value: selected.contains(m.userId),
          title: Text(m.name),
          subtitle: Text(m.email),
          secondary: Icon(m.role.icon, color: m.role.color(theme.colorScheme)),
          onChanged: (v) => setState(
            () => v ?? false ? selected.add(m.userId) : selected.remove(m.userId),
          ),
        );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Text(l10n.editTeam, style: theme.textTheme.titleLarge),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                ListTile(
                  title: Text(l10n.foremen, style: theme.textTheme.titleSmall),
                ),
                for (final m in foremen) tile(m, _foremen),
                ListTile(
                  title: Text(l10n.workers, style: theme.textTheme.titleSmall),
                ),
                for (final m in workers) tile(m, _workers),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.save),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
