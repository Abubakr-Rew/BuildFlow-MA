import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/core/widgets/status_badge.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:flutter/material.dart';

/// UI helpers for [UserRole]: localized name and icon.
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
}

/// Small neutral pill with the role name.
class RoleBadge extends StatelessWidget {
  const RoleBadge({required this.role, super.key});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      label: role.label(AppLocalizations.of(context)),
      tone: StatusTone.neutral,
      icon: role.icon,
    );
  }
}
