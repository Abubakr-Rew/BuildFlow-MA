import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/core/widgets/empty_state.dart';
import 'package:buildflow/core/widgets/error_state.dart';
import 'package:buildflow/core/widgets/loading_shimmer.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/team/domain/entities/invite_code.dart';
import 'package:buildflow/features/team/presentation/providers/team_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Team list screen — shows members and invite generation.
class TeamListScreen extends ConsumerWidget {
  const TeamListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final members = ref.watch(membersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.teamTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInviteDialog(context, ref),
        icon: const Icon(Icons.person_add),
        label: Text(l10n.inviteForeman),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(membersProvider.future),
        child: members.when(
          loading: () => const LoadingShimmerList(),
          error: (error, _) => ErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(membersProvider),
            retryLabel: l10n.retry,
          ),
          data: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.group_outlined,
                title: l10n.noMembers,
                actionLabel: l10n.inviteForeman,
                onAction: () => _showInviteDialog(context, ref),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              itemCount: list.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppTheme.spacing12),
              itemBuilder: (context, index) {
                final member = list[index];
                final isOwner = member.role == UserRole.owner;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isOwner
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.secondaryContainer,
                      child: Text(
                        member.name.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: isOwner
                              ? theme.colorScheme.primary
                              : theme.colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    title: Text(member.name),
                    subtitle: Text(member.email),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isOwner
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isOwner ? l10n.roleOwner : l10n.roleForeman,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isOwner
                              ? theme.colorScheme.primary
                              : theme.colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _showInviteDialog(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(teamRepositoryProvider);
    final result = await repo.generateInviteCode();

    if (!context.mounted) return;

    result.when(
      success: (invite) {
        ref.read(inviteCodeProvider.notifier).state = invite;
        _showInviteCodeSheet(context, invite);
      },
      failure: (f) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(f.message)),
        );
      },
    );
  }

  void _showInviteCodeSheet(BuildContext context, InviteCode invite) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
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
              l10n.inviteCode,
              style: theme.textTheme.titleLarge,
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
                mainAxisAlignment: MainAxisAlignment.center,
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
                      ScaffoldMessenger.of(ctx).showSnackBar(
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
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.done),
            ),
          ],
        ),
      ),
    );
  }
}
