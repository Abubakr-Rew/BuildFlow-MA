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
class TeamListScreen extends ConsumerWidget {
  const TeamListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        onPressed: () => _invite(context, ref),
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
                onAction: () => _invite(context, ref),
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
                  onRemove: canRemove
                      ? () => _confirmRemove(context, ref, member)
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
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
    if (role == null || !context.mounted) return;

    final result = await ref.read(teamRepositoryProvider).generateInviteCode();
    if (!context.mounted) return;

    result.when(
      success: (invite) => _showInviteCodeSheet(context, invite, role),
      failure: (f) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failureMessage(f))),
        );
      },
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    Member member,
  ) async {
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
    if (!(confirmed ?? false) || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(membersProvider.notifier).removeMember(member);
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? l10n.memberRemoved : l10n.actionFailed)),
    );
  }

  void _showInviteCodeSheet(
    BuildContext context,
    InviteCode invite,
    UserRole role,
  ) {
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
    this.onRemove,
  });

  final Member member;
  final int projectCount;
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
            if (onRemove != null)
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
