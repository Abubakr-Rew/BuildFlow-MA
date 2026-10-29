import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

/// «Повторить / Удалить» under [title], for something that failed: a chat
/// message that didn't send, a photo that couldn't be compressed.
/// `true` to retry, `false` to delete, `null` if dismissed.
Future<bool?> showRetryDeleteSheet(
  BuildContext context, {
  required String title,
}) {
  final l10n = AppLocalizations.of(context);
  final t = context.bfTheme;
  return showModalBottomSheet<bool>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              0,
              AppTheme.screenPadding,
              AppTheme.spacing8,
            ),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          ListTile(
            leading: const Icon(Icons.refresh_rounded),
            title: Text(l10n.retry),
            onTap: () => Navigator.pop(sheetContext, true),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: t.danger.fg),
            title: Text(l10n.delete, style: TextStyle(color: t.danger.fg)),
            onTap: () => Navigator.pop(sheetContext, false),
          ),
        ],
      ),
    ),
  );
}
