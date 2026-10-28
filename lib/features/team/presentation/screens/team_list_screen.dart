import 'package:buildflow/app/l10n/failure_messages.dart';
import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/core/widgets/empty_state.dart';
import 'package:buildflow/core/widgets/error_state.dart';
import 'package:buildflow/core/widgets/loading_shimmer.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/auth/presentation/role_label.dart';
import 'package:buildflow/features/projects/presentation/providers/project_provider.dart';
import 'package:buildflow/features/team/domain/entities/invite_code.dart';
import 'package:buildflow/features/team/domain/entities/member.dart';
import 'package:buildflow/features/team/presentation/providers/team_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Team list screen — members grouped by role, invites and removal.
class TeamListScreen extends ConsumerStatefulWidget {
  const TeamListScreen({super.key});

  @override
  ConsumerState<TeamListScreen> createState() => _TeamListScreenState();
}

class _TeamListScreenState extends ConsumerState<TeamListScreen> {
  /// Members being removed: their cards show progress instead of the menu,
  /// so the removal can't be started twice.
  final Set<String> _removing = {};
  bool _inviting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final members = ref.watch(membersProvider);
    final projects = ref.watch(projectsProvider).valueOrNull ?? const [];
    final currentUserId = ref.watch(currentUserProvider)?.id;

    int projectCount(Member m) => projects
        .where(
          (p) =>
              p.foremanIds.contains(m.userId) ||
              p.workerIds.contains(m.userId),
        )
        .length;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.teamTitle)),
      floatingActionButton: FloatingActionButton.extended(
        // The director's shell keeps the projects tab, which has a FAB too,
        // alive: two default hero tags break every page transition.
        heroTag: null,
        onPressed: _invite,
        icon: const Icon(Icons.person_add),
        label: Text(l10n.inviteMember),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(membersProvider.future),
        child: members.when(
          loading: () => const LoadingShimmerList(),
          error: (error, _) => ErrorState(
            message: l10n.failureMessage(error),
            onRetry: () => ref.invalidate(membersProvider),
            retryLabel: l10n.retry,
          ),
          data: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.group_outlined,
                title: l10n.noMembers,
                actionLabel: l10n.inviteMember,
                onAction: _invite,
              );
            }

            // Directors first, then foremen, then workers.
            final sorted = [...list]
              ..sort((a, b) => a.role.index.compareTo(b.role.index));

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                AppTheme.spacing16,
                AppTheme.spacing16,
                96, // keep the last card above the FAB
              ),
              itemCount: sorted.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppTheme.spacing12),
              itemBuilder: (context, index) {
                final member = sorted[index];
                final canRemove =
                    !member.role.isOwner && member.userId != currentUserId;
                return _MemberCard(
                  member: member,
                  projectCount: projectCount(member),
                  isRemoving: _removing.contains(member.id),
                  onRemove: canRemove ? () => _confirmRemove(member) : null,
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Ignores taps while an earlier invite is still being chosen or created.
  Future<void> _invite() async {
    if (_inviting) return;
    _inviting = true;
    try {
      await _createInvite();
    } finally {
      _inviting = false;
    }
  }

  Future<void> _createInvite() async {
    final l10n = AppLocalizations.of(context);

    final role = await showModalBottomSheet<UserRole>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                l10n.inviteWho,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final role in [UserRole.foreman, UserRole.worker])
              ListTile(
                leading: Icon(role.icon),
                title: Text(role.label(l10n)),
                onTap: () => Navigator.pop(ctx, role),
              ),
          ],
        ),
      ),
    );
    if (role == null || !mounted) return;

    final result =
        await ref.read(teamRepositoryProvider).generateInviteCode(role: role);
    if (!mounted) return;

    result.when(
      success: (invite) => _showInviteCodeSheet(invite, role),
      failure: (f) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failureMessage(f))),
        );
      },
    );
  }

  Future<void> _confirmRemove(Member member) async {
    if (_removing.contains(member.id)) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeMember),
        content: Text(l10n.removeMemberConfirm(member.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !mounted || _removing.contains(member.id)) {
      return;
    }

    setState(() => _removing.add(member.id));
    final messenger = ScaffoldMessenger.of(context);
    final result =
        await ref.read(membersProvider.notifier).removeMember(member);
    if (mounted) setState(() => _removing.remove(member.id));
    final message = result.when(
      success: (_) => l10n.memberRemoved,
      failure: l10n.failureMessage,
    );
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _showInviteCodeSheet(InviteCode invite, UserRole role) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.card_membership_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppTheme.spacing16),
              Text(
                '${l10n.inviteCode} · ${role.label(l10n)}',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacing8),
              Text(
                l10n.inviteCodeHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacing24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      invite.code,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: invite.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.codeCopied)),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      tooltip: l10n.copy,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacing24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.done),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.projectCount,
    this.isRemoving = false,
    this.onRemove,
  });

  final Member member;
  final int projectCount;
  final bool isRemoving;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 16, right: 4),
        leading: CircleAvatar(
          backgroundColor: member.role.containerColor(scheme),
          child: Icon(member.role.icon, color: member.role.color(scheme)),
        ),
        title: Text(member.name),
        subtitle: Text(
          member.role.isOwner
              ? member.email
              : '${member.email}\n${l10n.navProjects}: $projectCount',
        ),
        isThreeLine: !member.role.isOwner,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RoleBadge(role: member.role),
            if (isRemoving)
              const SizedBox.square(
                dimension: AppTheme.minTouchTarget,
                child: Center(
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (onRemove != null)
              // onSelected runs after the menu has closed, so the
              // confirmation dialog isn't popped together with the menu.
              PopupMenuButton<bool>(
                onSelected: (_) => onRemove!(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: true,
                    child: Row(
                      children: [
                        Icon(Icons.person_remove, color: scheme.error),
                        const SizedBox(width: 12),
                        Text(l10n.removeMember),
                      ],
                    ),
                  ),
                ],
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
