import 'package:buildflow/app/l10n/failure_messages.dart';
import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_text_theme.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/widgets/avatar_initials.dart';
import 'package:buildflow/core/widgets/bf_button.dart';
import 'package:buildflow/core/widgets/bf_card.dart';
import 'package:buildflow/core/widgets/bf_icon_button.dart';
import 'package:buildflow/core/widgets/bf_progress_bar.dart';
import 'package:buildflow/core/widgets/empty_state.dart';
import 'package:buildflow/core/widgets/error_state.dart';
import 'package:buildflow/core/widgets/photo_thumbnail.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// An item of the director's "more" menu on the project page.
sealed class ProjectMenuAction {
  const ProjectMenuAction();
}

class SetProjectStatus extends ProjectMenuAction {
  const SetProjectStatus(this.status);

  final ProjectStatus status;
}

class EditProjectProgress extends ProjectMenuAction {
  const EditProjectProgress();
}

/// Project page: header, actions, readiness, reports and team.
///
/// Directors can change the status, the readiness and the team; foremen can
/// start a report for this project.
class ProjectDetailScreen extends ConsumerStatefulWidget {
  const ProjectDetailScreen({required this.projectId, super.key});

  final String projectId;

  @override
  ConsumerState<ProjectDetailScreen> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  static const _reportsTab = 0;

  late final _tabs = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  /// While a status or readiness change is in flight the menu and the team
  /// editor are locked: each sends the whole project, so a second update
  /// started from the old copy would undo the first.
  bool _updating = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final project = ref.watch(projectByIdProvider(widget.projectId));
    final role = ref.watch(currentUserProvider)?.role;
    final loaded = project.valueOrNull;

    if (loaded == null) {
      return Scaffold(
        appBar: AppBar(),
        body: project.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorState(
            message: l10n.failureMessage(error),
            onRetry: () => ref.invalidate(projectsProvider),
            retryLabel: l10n.retry,
          ),
          data: (_) => EmptyState(
            icon: Icons.construction_outlined,
            title: l10n.projectNotFound,
          ),
        ),
      );
    }

    final isOwner = role == UserRole.owner;
    final canReport = role == UserRole.foreman && loaded.status.isActive;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(projectsProvider)
            ..invalidate(membersProvider);
          await ref.read(reportsProvider.future);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _ProjectHeader(
              project: loaded,
              coverUrl: ref.watch(projectCoverProvider(loaded.id)),
              menu: isOwner ? _menu(loaded) : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.screenPadding,
                AppTheme.spacing16,
                AppTheme.screenPadding,
                AppTheme.spacing32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tiles are for actions only; the tabs below already
                  // switch between reports and team.
                  if (canReport) ...[
                    _ActionTile(
                      icon: Icons.add_a_photo_rounded,
                      label: l10n.newReport,
                      accent: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              NewReportScreen(initialProjectId: loaded.id),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing12),
                  ],
                  _ProgressCard(percent: loaded.progress),
                  const SizedBox(height: AppTheme.spacing8),
                  TabBar(
                    controller: _tabs,
                    tabs: [
                      Tab(text: l10n.navReports),
                      Tab(text: l10n.navTeam),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  if (_tabs.index == _reportsTab)
                    _ReportsTab(projectId: loaded.id)
                  else
                    _TeamTab(
                      project: loaded,
                      isOwner: isOwner,
                      canEditTeam: !_updating,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menu(Project project) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<ProjectMenuAction>(
      tooltip: l10n.more,
      enabled: !_updating,
      onSelected: (action) => switch (action) {
        SetProjectStatus(:final status) => _changeStatus(project, status),
        EditProjectProgress() => _changeProgress(project),
      },
      itemBuilder: (_) => [
        for (final status in ProjectStatus.values)
          CheckedPopupMenuItem(
            value: SetProjectStatus(status),
            checked: status == project.status,
            child: Text(projectStatusLabel(l10n, status)),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: const EditProjectProgress(),
          child: Row(
            children: [
              const Icon(Icons.speed_rounded),
              const SizedBox(width: AppTheme.spacing12),
              Text(l10n.changeProgress),
            ],
          ),
        ),
      ],
      child: const BfIconButtonSurface(
        translucent: true,
        child: _HeaderIcon(Icons.more_vert),
      ),
    );
  }

  Future<void> _changeStatus(Project project, ProjectStatus status) async {
    if (_updating || status == project.status) return;
    final l10n = AppLocalizations.of(context);
    await _update(
      () => ref.read(projectsProvider.notifier).setStatus(project, status),
      saved: l10n.statusChanged,
    );
  }

  Future<void> _changeProgress(Project project) async {
    if (_updating) return;
    final l10n = AppLocalizations.of(context);
    final percent = await showDialog<int>(
      context: context,
      builder: (_) => _ProgressDialog(initial: project.progress),
    );
    if (!mounted || percent == null || percent == project.progress) return;
    await _update(
      () => ref.read(projectsProvider.notifier).setProgress(project, percent),
      saved: l10n.progressSaved,
    );
  }

  /// Runs a project update under the [_updating] lock and reports the
  /// outcome in one snack bar.
  Future<void> _update<T>(
    Future<Result<T>> Function() run, {
    required String saved,
  }) async {
    if (_updating) return;
    setState(() => _updating = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await run();
    if (mounted) setState(() => _updating = false);
    final message = result.when(
      success: (_) => saved,
      failure: l10n.failureMessage,
    );
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

// ── Header ────────────────────────────────────────────────────

/// Project header: 250 px over the latest report photo, darkened towards
/// the bottom so the text stays readable; 180 px of graphite without one.
class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({required this.project, this.coverUrl, this.menu});

  static const _coverHeight = 250.0;
  static const _plainHeight = 180.0;

  final Project project;
  final String? coverUrl;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.bfTheme;
    final l10n = AppLocalizations.of(context);
    final top = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SizedBox(
        height: (coverUrl == null ? _plainHeight : _coverHeight) + top,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: t.graphite),
            if (coverUrl != null) ...[
              PhotoImage(url: coverUrl!, iconSize: 64),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    // Light at the top for the status bar and buttons,
                    // full scrim from the middle down, under the text.
                    colors: [
                      t.graphite.withValues(alpha: 0.45),
                      t.graphite.withValues(alpha: 0.2),
                      t.graphite.withValues(
                        alpha: BuildFlowThemeExtension.coverScrimOpacity,
                      ),
                      t.graphite.withValues(
                        alpha: BuildFlowThemeExtension.coverScrimOpacity,
                      ),
                    ],
                    stops: const [0, 0.25, 0.55, 1],
                  ),
                ),
              ),
            ],
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppTheme.screenPadding,
                top + AppTheme.spacing8,
                AppTheme.screenPadding,
                AppTheme.spacing24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      BfIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: l10n.back,
                        translucent: true,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      if (menu != null) menu!,
                    ],
                  ),
                  const Spacer(),
                  ProjectStatusBadge(status: project.status),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    project.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: t.onGraphite,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: t.onGraphiteSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          project.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: t.onGraphiteSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon on a translucent header button.
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, size: 22, color: context.bfTheme.onAccent);
}

// ── Actions and readiness ─────────────────────────────────────

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Accent icon: the tile starts the screen's main action.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    return BfCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent ? t.accent : t.muted,
              borderRadius: BorderRadius.circular(
                BuildFlowThemeExtension.iconButtonRadius - 2,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: accent ? t.onAccent : t.textPrimary,
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return BfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.progressLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.bfTheme.textSecondary,
                  ),
                ),
              ),
              Text(
                l10n.percentValue(percent),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFeatures: AppTextTheme.tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing8),
          BfProgressBar(percent: percent),
        ],
      ),
    );
  }
}

/// Readiness slider, 5 % steps. Pops the chosen percent, or `null`.
class _ProgressDialog extends StatefulWidget {
  const _ProgressDialog({required this.initial});

  final int initial;

  @override
  State<_ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends State<_ProgressDialog> {
  static const _step = 5;

  late double _value = ((widget.initial / _step).round() * _step).toDouble();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final percent = _value.round();
    return AlertDialog(
      title: Text(l10n.changeProgress),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.percentValue(percent),
            style: Theme.of(context).textTheme.headlineLarge
                ?.copyWith(fontFeatures: AppTextTheme.tabular),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Slider(
            value: _value,
            max: 100,
            divisions: 100 ~/ _step,
            label: l10n.percentValue(percent),
            onChanged: (v) => setState(() => _value = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, percent),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

// ── Tabs ──────────────────────────────────────────────────────

class _ReportsTab extends ConsumerWidget {
  const _ReportsTab({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reports = ref.watch(projectReportsProvider(projectId));

    return reports.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppTheme.spacing24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Text(l10n.failureMessage(error)),
      data: (list) => list.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Text(
                l10n.noReportsForProject,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.bfTheme.textSecondary,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final report in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.cardGap),
                    child: ReportCard(report: report, showProject: false),
                  ),
              ],
            ),
    );
  }
}

class _TeamTab extends ConsumerWidget {
  const _TeamTab({
    required this.project,
    required this.isOwner,
    required this.canEditTeam,
  });

  final Project project;
  final bool isOwner;
  final bool canEditTeam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final members = ref.watch(membersProvider).valueOrNull ?? const [];

    List<Member> byIds(List<String> ids) =>
        members.where((m) => ids.contains(m.userId)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.projectTeam, style: theme.textTheme.titleMedium),
            ),
            if (isOwner)
              TextButton.icon(
                onPressed: canEditTeam
                    ? () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => _EditTeamSheet(project: project),
                      )
                    : null,
                icon: const Icon(Icons.edit, size: 18),
                label: Text(l10n.editTeam),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing8),
        _TeamGroup(title: l10n.foremen, members: byIds(project.foremanIds)),
        const SizedBox(height: AppTheme.cardGap),
        _TeamGroup(title: l10n.workers, members: byIds(project.workerIds)),
      ],
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
    final t = context.bfTheme;
    final l10n = AppLocalizations.of(context);

    return BfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: t.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          if (members.isEmpty)
            Text(
              l10n.nobodyAssigned,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: t.textSecondary,
              ),
            )
          else
            for (final m in members)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    AvatarInitials(name: m.name, size: 36),
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            m.role.label(l10n),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: t.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

// ── Team editor ───────────────────────────────────────────────

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
    if (_saving) return; // a second tap before the button is disabled
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(projectsProvider.notifier)
        .setTeam(
          widget.project,
          foremanIds: _foremen.toList(),
          workerIds: _workers.toList(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    final message = result.when(
      success: (_) => l10n.teamSaved,
      failure: l10n.failureMessage,
    );
    messenger.showSnackBar(SnackBar(content: Text(message)));
    if (result.isSuccess) Navigator.pop(context);
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
      secondary: AvatarInitials(name: m.name),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.screenPadding,
      ),
      onChanged: (v) => setState(
        () => v ?? false ? selected.add(m.userId) : selected.remove(m.userId),
      ),
    );

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        AppTheme.spacing16,
        AppTheme.screenPadding,
        AppTheme.spacing4,
      ),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: context.bfTheme.textSecondary,
        ),
      ),
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: Text(l10n.editTeam, style: theme.textTheme.titleLarge),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                section(l10n.foremen),
                for (final m in foremen) tile(m, _foremen),
                section(l10n.workers),
                for (final m in workers) tile(m, _workers),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.screenPadding,
                AppTheme.spacing12,
                AppTheme.screenPadding,
                AppTheme.spacing16,
              ),
              child: BfButton(
                label: l10n.save,
                onPressed: _save,
                isLoading: _saving,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
