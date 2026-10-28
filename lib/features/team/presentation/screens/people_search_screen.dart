import 'dart:async';

import 'package:buildflow/app/l10n/failure_messages.dart';
import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/routes.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/widgets/avatar_initials.dart';
import 'package:buildflow/core/widgets/bf_button.dart';
import 'package:buildflow/core/widgets/bf_card.dart';
import 'package:buildflow/core/widgets/bf_chip.dart';
import 'package:buildflow/core/widgets/bf_text_field.dart';
import 'package:buildflow/core/widgets/empty_state.dart';
import 'package:buildflow/core/widgets/error_state.dart';
import 'package:buildflow/core/widgets/highlighted_text.dart';
import 'package:buildflow/core/widgets/loading_shimmer.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/auth/presentation/role_label.dart';
import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/presentation/providers/chat_provider.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/presentation/providers/project_provider.dart';
import 'package:buildflow/features/team/domain/entities/member.dart';
import 'package:buildflow/features/team/domain/member_search.dart';
import 'package:buildflow/features/team/presentation/providers/team_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// People search within the user's company: by name or surname, with a role
/// filter and recently opened people for an empty query.
class PeopleSearchScreen extends ConsumerStatefulWidget {
  const PeopleSearchScreen({super.key});

  @override
  ConsumerState<PeopleSearchScreen> createState() =>
      _PeopleSearchScreenState();
}

class _PeopleSearchScreenState extends ConsumerState<PeopleSearchScreen> {
  static const _debounce = Duration(milliseconds: 250);

  final _controller = TextEditingController();
  Timer? _debounceTimer;

  /// The query the results are for: the field text after [_debounce].
  String _query = '';
  UserRole? _role;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    setState(() {}); // shows or hides the clear button
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      if (mounted) setState(() => _query = text);
    });
  }

  void _clear() {
    _debounceTimer?.cancel();
    _controller.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final members = ref.watch(membersProvider);
    // Loads the projects for the card captions along with the members,
    // not when the first result shows up.
    ref.watch(projectsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchPeople)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              AppTheme.spacing8,
              AppTheme.screenPadding,
              0,
            ),
            child: BfTextField(
              label: l10n.searchPeopleField,
              controller: _controller,
              autofocus: true,
              prefixIcon: Icons.search,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l10n.clearSearch,
                      icon: const Icon(Icons.close),
                      onPressed: _clear,
                    ),
            ),
          ),
          Expanded(
            child: members.when(
              loading: () => const LoadingShimmerList(),
              error: (error, _) => ErrorState(
                message: l10n.failureMessage(error),
                onRetry: () => ref.invalidate(membersProvider),
                retryLabel: l10n.retry,
              ),
              data: _buildResults,
            ),
          ),
          const _CompanyOnlyNote(),
        ],
      ),
    );
  }

  Widget _buildResults(List<Member> members) {
    final l10n = AppLocalizations.of(context);
    final myId = ref.watch(currentUserProvider)?.id;
    final people = members.where((m) => m.userId != myId).toList();

    // Only the roles someone in the company has.
    final roles = [
      for (final role in UserRole.values)
        if (people.any((m) => m.role == role)) role,
    ];
    final role = roles.contains(_role) ? _role : null;
    final query = _query.trim();

    final Widget content;
    if (query.length < minPeopleSearchLength && role == null) {
      final recentIds = ref.watch(recentPeopleProvider);
      final recent = [
        for (final id in recentIds) ...people.where((m) => m.id == id),
      ];
      content = recent.isEmpty
          ? _FillScrollable(
              child: EmptyState(
                icon: Icons.person_search_outlined,
                title: l10n.searchPeopleStart,
                description: l10n.searchPeopleStartHint,
              ),
            )
          : _PeopleList(
              header: l10n.recentPeople,
              matches: [
                for (final m in recent) (member: m, ranges: const []),
              ],
              onOpen: _openPerson,
            );
    } else {
      final matches = searchMembers(people, query, role: role);
      content = matches.isEmpty
          ? _FillScrollable(
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: l10n.nobodyFound,
                description: l10n.nobodyFoundHint,
              ),
            )
          : _PeopleList(matches: matches, onOpen: _openPerson);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (roles.length > 1)
          _RoleFilter(
            roles: roles,
            selected: role,
            onSelected: (r) => setState(() => _role = r),
          ),
        Expanded(child: content),
      ],
    );
  }

  void _openPerson(Member member) {
    ref.read(recentPeopleProvider.notifier).add(member.id);
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _PersonSheet(
        member: member,
        onOpenProject: (project) {
          Navigator.pop(sheetContext);
          context.push(Routes.project(project.id));
        },
        onOpenChat: (chat) {
          Navigator.pop(sheetContext);
          context.push(Routes.chat(chat.id));
        },
      ),
    );
  }
}

// ── Role filter ───────────────────────────────────────────────

class _RoleFilter extends StatelessWidget {
  const _RoleFilter({
    required this.roles,
    required this.selected,
    required this.onSelected,
  });

  final List<UserRole> roles;
  final UserRole? selected;
  final ValueChanged<UserRole?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        AppTheme.spacing8,
        AppTheme.screenPadding,
        0,
      ),
      child: Row(
        children: [
          BfChip(
            label: l10n.filterAll,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final role in roles) ...[
            const SizedBox(width: AppTheme.spacing8),
            BfChip(
              label: role.label(l10n),
              selected: selected == role,
              onTap: () => onSelected(role),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Results ───────────────────────────────────────────────────

class _PeopleList extends StatelessWidget {
  const _PeopleList({
    required this.matches,
    required this.onOpen,
    this.header,
  });

  final List<MemberMatch> matches;
  final ValueChanged<Member> onOpen;
  final String? header;

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        AppTheme.spacing16,
        AppTheme.screenPadding,
        AppTheme.spacing24,
      ),
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
            child: Text(
              header!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.bfTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        for (final (i, match) in matches.indexed) ...[
          if (i > 0) const SizedBox(height: AppTheme.cardGap),
          _PersonCard(match: match, onTap: () => onOpen(match.member)),
        ],
      ],
    );
  }
}

class _PersonCard extends ConsumerWidget {
  const _PersonCard({required this.match, required this.onTap});

  final MemberMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final member = match.member;
    // Directors aren't assigned to projects: they run all of them.
    final projects = member.role.isOwner
        ? const <Project>[]
        : ref.watch(memberProjectsProvider(member.userId));
    final subtitle = [
      member.role.label(l10n),
      if (projects.isNotEmpty) projects.map((p) => p.name).join(', '),
    ].join(' · ');

    return BfCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      child: Row(
        children: [
          AvatarInitials(name: member.name),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HighlightedText(
                  text: member.name,
                  ranges: match.ranges,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.bfTheme.textSecondary,
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

/// Lets an [EmptyState] scroll when the keyboard leaves it too little room.
class _FillScrollable extends StatelessWidget {
  const _FillScrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }
}

class _CompanyOnlyNote extends StatelessWidget {
  const _CompanyOnlyNote();

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.screenPadding,
          AppTheme.spacing8,
          AppTheme.screenPadding,
          AppTheme.spacing12,
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 16, color: t.textTertiary),
            const SizedBox(width: AppTheme.spacing8),
            Expanded(
              child: Text(
                AppLocalizations.of(context).searchCompanyOnly,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: t.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Person sheet ──────────────────────────────────────────────

class _PersonSheet extends ConsumerStatefulWidget {
  const _PersonSheet({
    required this.member,
    required this.onOpenProject,
    required this.onOpenChat,
  });

  final Member member;
  final ValueChanged<Project> onOpenProject;
  final ValueChanged<Chat> onOpenChat;

  @override
  ConsumerState<_PersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends ConsumerState<_PersonSheet> {
  bool _opening = false;
  Failure? _failure;

  Member get member => widget.member;

  /// Opens the direct chat, creating it on first use.
  Future<void> _write() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _failure = null;
    });
    final result =
        await ref.read(chatsProvider.notifier).openDirect(member.userId);
    if (!mounted) return;
    result.when(
      success: widget.onOpenChat,
      failure: (f) => setState(() {
        _opening = false;
        _failure = f;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final t = context.bfTheme;
    final me = ref.watch(currentUserProvider);
    final viewerIsOwner = me?.role.isOwner ?? false;
    final projects = ref.watch(memberProjectsProvider(member.userId));
    final failure = _failure;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            0,
            AppTheme.screenPadding,
            AppTheme.spacing24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: AvatarInitials(name: member.name, size: 72)),
              const SizedBox(height: AppTheme.spacing16),
              Text(
                member.name,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacing8),
              Center(child: RoleBadge(role: member.role)),
              const SizedBox(height: AppTheme.spacing12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mail_outline_rounded,
                      size: 16, color: t.textSecondary),
                  const SizedBox(width: AppTheme.spacing8),
                  Flexible(
                    child: Text(
                      member.email,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: t.textSecondary),
                    ),
                  ),
                ],
              ),
              // Nobody writes to themselves.
              if (me != null && me.id != member.userId) ...[
                const SizedBox(height: AppTheme.spacing24),
                BfButton(
                  label: l10n.writeMessage,
                  icon: Icons.chat_bubble_outline_rounded,
                  isLoading: _opening,
                  onPressed: _write,
                ),
                if (failure != null) ...[
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    l10n.failureMessage(failure),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: t.danger.fg),
                  ),
                ],
              ],
              // Directors run every project rather than being assigned.
              if (!member.role.isOwner) ...[
                const SizedBox(height: AppTheme.spacing24),
                Text(l10n.memberProjects, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppTheme.spacing8),
                if (projects.isEmpty)
                  Text(
                    viewerIsOwner
                        ? l10n.memberNotAssigned
                        : l10n.noSharedProjects,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: t.textSecondary),
                  )
                else
                  for (final (i, project) in projects.indexed) ...[
                    if (i > 0) const SizedBox(height: AppTheme.spacing8),
                    _ProjectRow(
                      project: project,
                      onTap: () => widget.onOpenProject(project),
                    ),
                  ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project, required this.onTap});

  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.bfTheme;
    return BfCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      child: Row(
        children: [
          Icon(Icons.apartment_rounded, color: t.textSecondary),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  project.address,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: t.textTertiary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: t.textTertiary),
        ],
      ),
    );
  }
}
