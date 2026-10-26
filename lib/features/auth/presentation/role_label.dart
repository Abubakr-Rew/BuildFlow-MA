import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:flutter/material.dart';

/// UI helpers for [UserRole]: localized name, colors and icon.
extension UserRoleUi on UserRole {
  String label(AppLocalizations l10n) => switch (this) {
        UserRole.owner => l10n.roleOwner,
        UserRole.foreman => l10n.roleForeman,
        UserRole.worker => l10n.roleWorker,
      };

  IconData get icon => switch (this) {
        UserRole.owner => Icons.business_center_rounded,
        UserRole.foreman => Icons.engineering_rounded,
        UserRole.worker => Icons.handyman_rounded,
      };

  /// Foreground color for role badges and avatars.
  Color color(ColorScheme scheme) => switch (this) {
        UserRole.owner => scheme.primary,
        UserRole.foreman => scheme.secondary,
        UserRole.worker => scheme.tertiary,
      };

  /// Background color for role badges and avatars.
  Color containerColor(ColorScheme scheme) => switch (this) {
        UserRole.owner => scheme.primaryContainer,
        UserRole.foreman => scheme.secondaryContainer,
        UserRole.worker => scheme.tertiaryContainer,
      };
}

/// Small rounded badge with the role name.
class RoleBadge extends StatelessWidget {
  const RoleBadge({required this.role, super.key});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: role.containerColor(scheme),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role.label(AppLocalizations.of(context)),
        style: theme.textTheme.labelSmall?.copyWith(
          color: role.color(scheme),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
