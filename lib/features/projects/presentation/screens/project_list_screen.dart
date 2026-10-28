import 'package:buildflow/app/l10n/failure_messages.dart';
import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/routes.dart';
import 'package:buildflow/app/theme/app_text_theme.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/utils/date_formatter.dart';
import 'package:buildflow/core/widgets/avatar_initials.dart';
import 'package:buildflow/core/widgets/bf_button.dart';
import 'package:buildflow/core/widgets/bf_card.dart';
import 'package:buildflow/core/widgets/bf_chip.dart';
import 'package:buildflow/core/widgets/bf_progress_bar.dart';
import 'package:buildflow/core/widgets/bf_text_field.dart';
import 'package:buildflow/core/widgets/empty_state.dart';
import 'package:buildflow/core/widgets/error_state.dart';
import 'package:buildflow/core/widgets/loading_shimmer.dart';
import 'package:buildflow/core/widgets/screen_header.dart';
import 'package:buildflow/core/widgets/status_badge.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/domain/entities/project_status.dart';
import 'package:buildflow/features/projects/presentation/providers/project_provider.dart';
import 'package:buildflow/features/projects/presentation/widgets/project_status_badge.dart';
import 'package:buildflow/features/reports/presentation/providers/report_provider.dart';
import 'package:buildflow/features/team/presentation/providers/team_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Project list — all projects for a director, assigned ones otherwise.
class ProjectListScreen extends ConsumerStatefulWidget {
  const ProjectListScreen({super.key});

  @override
  ConsumerState<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends ConsumerState<ProjectListScreen> {
  /// Status filter; `null` shows every project.
  ProjectStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final projects = ref.watch(projectsProvider);
    final user = ref.watch(currentUserProvider);
    final isOwner = user?.role.isOwner ?? false;

    return Scaffold(
      floatingActionButton: isOwner
          ? FloatingActionButton(
              heroTag: null, // shares the shell with the team tab's FAB
              tooltip: l10n.addProject,
              onPressed: () => _showCreateSheet(context),
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              overline: user == null ? null : _greeting(l10n, user.name),
              title: l10n.projectsTitle,
            ),
            Expanded(
              child: RefreshIndicator(
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
                        description: isOwner
                            ? l10n.noProjectsHint
                            : l10n.noAssignedProjects,
                        actionLabel: isOwner ? l10n.addProject : null,
                        onAction: isOwner
                            ? () => _showCreateSheet(context)
                            : null,
                      );
                    }
                    final shown = _filter == null
                        ? list
                        : list.where((p) => p.status == _filter).toList();
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.screenPadding,
                        0,
                        AppTheme.screenPadding,
                        96, // keep the last card above the FAB
                      ),
                      children: [
                        const _DaySummaryCard(),
                        const SizedBox(height: AppTheme.spacing12),
                        _StatusFilter(
                          selected: _filter,
                          onSelected: (s) => setState(() => _filter = s),
                        ),
                        const SizedBox(height: AppTheme.spacing12),
                        for (final project in shown) ...[
                          _ProjectCard(project: project),
                          const SizedBox(height: AppTheme.cardGap),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _greeting(AppLocalizations l10n, String fullName) {
    final name = fullName.trim().split(RegExp(r'\s+')).first;
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return l10n.greetingMorning(name);
    if (hour >= 12 && hour < 18) return l10n.greetingDay(name);
    return l10n.greetingEvening(name);
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateProjectSheet(),
    );
  }
}

// ── Day summary ───────────────────────────────────────────────

class _DaySummaryCard extends ConsumerWidget {
  const _DaySummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final t = context.bfTheme;
    final summary = ref.watch(daySummaryProvider).valueOrNull;
    if (summary == null) return const SizedBox.shrink();

    final missing = summary.activeProjects - summary.reportsSent;

    return BfCard(
      color: t.graphite,
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l10n.today}, ${DateFormatter.dayMonth(DateTime.now())}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: t.onGraphiteSecondary,
                  ),
                ),
              ),
              if (missing > 0)
                StatusBadge(
                  label: l10n.summaryWithoutReport(missing),
                  tone: StatusTone.accent,
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryStat(
                value: '${summary.reportsSent}/${summary.activeProjects}',
                label: l10n.summaryReportsSent,
              ),
              _SummaryStat(
                value: '${summary.newPhotos}',
                label: l10n.summaryNewPhotos,
              ),
              _SummaryStat(
                value: '${summary.activeProjects}',
                label: l10n.summaryActiveProjects,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.bfTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: t.onGraphite,
              fontFeatures: AppTextTheme.tabular,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: t.onGraphiteSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter ────────────────────────────────────────────────────

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.selected, required this.onSelected});

  final ProjectStatus? selected;
  final ValueChanged<ProjectStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Lets the chips scroll to the screen edge.
      clipBehavior: Clip.none,
      child: Row(
        children: [
          BfChip(
            label: l10n.filterAll,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final status in ProjectStatus.values) ...[
            const SizedBox(width: AppTheme.spacing8),
            BfChip(
              label: projectStatusLabel(l10n, status),
              selected: selected == status,
              onTap: () => onSelected(status),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Project card ──────────────────────────────────────────────

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = context.bfTheme;
    final l10n = AppLocalizations.of(context);
    final members = ref.watch(membersProvider).valueOrNull ?? const [];
    final team = [...project.foremanIds, ...project.workerIds]
        .map((id) => members.where((m) => m.userId == id).firstOrNull?.name)
        .nonNulls
        .toList();
    final reportTime = ref.watch(todayReportTimeProvider(project.id));
    final reportsLoaded = ref.watch(reportsProvider).hasValue;
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: t.textSecondary,
    );

    return BfCard(
      onTap: () => context.push(Routes.project(project.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(project.name, style: theme.textTheme.titleMedium),
              ),
              const SizedBox(width: AppTheme.spacing8),
              ProjectStatusBadge(status: project.status),
            ],
          ),
          const SizedBox(height: AppTheme.spacing4),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: t.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(child: Text(project.address, style: secondary)),
            ],
          ),
          const SizedBox(height: AppTheme.spacing16),
          Row(
            children: [
              Expanded(child: Text(l10n.progressLabel, style: secondary)),
              Text(
                l10n.percentValue(project.progress),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontFeatures: AppTextTheme.tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          BfProgressBar(percent: project.progress),
          if (team.isNotEmpty || reportTime != null) ...[
            const SizedBox(height: AppTheme.spacing16),
            Row(
              children: [
                AvatarStack(names: team),
                const Spacer(),
                if (reportTime != null) ...[
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: t.active.fg,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.reportAt(DateFormatter.time(reportTime)),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: t.active.fg,
                      fontFeatures: AppTextTheme.tabular,
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (project.status.isActive &&
              reportsLoaded &&
              reportTime == null) ...[
            const SizedBox(height: AppTheme.spacing12),
            _NoReportPlate(label: l10n.noReportForToday),
          ],
        ],
      ),
    );
  }
}

class _NoReportPlate extends StatelessWidget {
  const _NoReportPlate({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final danger = context.bfTheme.danger;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: danger.bg,
        borderRadius: BorderRadius.circular(
          BuildFlowThemeExtension.photoRadius,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: danger.fg),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: danger.fg),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create sheet ──────────────────────────────────────────────

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
    final result = await ref
        .read(projectsProvider.notifier)
        .createProject(
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
        AppTheme.screenPadding,
        0,
        AppTheme.screenPadding,
        MediaQuery.of(context).viewInsets.bottom + AppTheme.spacing24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.addProject,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppTheme.spacing24),
            BfTextField(
              label: l10n.projectName,
              hint: l10n.projectNameHint,
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.construction,
              validator: (v) => v == null || v.trim().isEmpty
                  ? l10n.validationProjectName
                  : null,
            ),
            const SizedBox(height: AppTheme.spacing16),
            BfTextField(
              label: l10n.projectAddress,
              hint: l10n.projectAddressHint,
              controller: _addressController,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              prefixIcon: Icons.location_on,
              validator: (v) => v == null || v.trim().isEmpty
                  ? l10n.validationProjectAddress
                  : null,
            ),
            const SizedBox(height: AppTheme.spacing24),
            BfButton(label: l10n.save, onPressed: _save, isLoading: _saving),
          ],
        ),
      ),
    );
  }
}
