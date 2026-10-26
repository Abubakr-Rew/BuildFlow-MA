import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/core/widgets/bf_button.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/auth/presentation/role_label.dart';
import 'package:buildflow/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Profile screen — role info, theme toggle, logout.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      (user?.name ?? '?').substring(0, 1).toUpperCase(),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(user?.name ?? '', style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppTheme.spacing4),
                  Text(
                    user?.email ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (user != null) ...[
                    const SizedBox(height: AppTheme.spacing12),
                    RoleBadge(role: user.role),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Card(
            child: SwitchListTile(
              title: Text(l10n.darkTheme),
              secondary: Icon(
                themeMode == ThemeMode.dark
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
              ),
              value: themeMode == ThemeMode.dark,
              onChanged: (isDark) => ref
                  .read(themeModeProvider.notifier)
                  .setMode(isDark ? ThemeMode.dark : ThemeMode.light),
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            l10n.appVersion('0.1.0'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing24),
          BfButton(
            label: l10n.logout,
            variant: BfButtonVariant.secondary,
            icon: Icons.logout_rounded,
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.logout),
                  content: Text(l10n.logoutConfirm),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l10n.logout),
                    ),
                  ],
                ),
              );
              if (confirmed ?? false) {
                // The router's redirect then sends the user to login.
                await ref.read(authProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
    );
  }
}
