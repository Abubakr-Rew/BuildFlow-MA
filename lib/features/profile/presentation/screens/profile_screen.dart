import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/widgets/avatar_initials.dart';
import 'package:buildflow/core/widgets/bf_button.dart';
import 'package:buildflow/core/widgets/bf_card.dart';
import 'package:buildflow/core/widgets/screen_header.dart';
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
    final t = context.bfTheme;
    final user = auth.user;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppTheme.spacing24),
          children: [
            ScreenHeader(title: l10n.profileTitle),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BfCard(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    child: Row(
                      children: [
                        AvatarInitials(name: user?.name ?? '', size: 64),
                        const SizedBox(width: AppTheme.spacing16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? '',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? '',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: t.textSecondary,
                                ),
                              ),
                              if (user != null) ...[
                                const SizedBox(height: AppTheme.spacing8),
                                RoleBadge(role: user.role),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.cardGap),
                  BfCard(
                    padding: EdgeInsets.zero,
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
                  const SizedBox(height: AppTheme.spacing24),
                  BfButton(
                    label: l10n.logout,
                    variant: BfButtonVariant.outline,
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
                            TextButton(
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
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    l10n.appVersion('0.1.0'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: t.textTertiary,
                    ),
                    textAlign: TextAlign.center,
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
