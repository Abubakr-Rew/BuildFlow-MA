import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

/// Shown instead of the app when the build's `--dart-define`s don't make a
/// working app (`BackendConfigError`): a release without a server address
/// must say so, not quietly run on demo data.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({required this.details, super.key});

  /// What is wrong, for the developer; not translated.
  final String details;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _ConfigErrorScreen(details: details),
    );
  }
}

class _ConfigErrorScreen extends StatelessWidget {
  const _ConfigErrorScreen({required this.details});

  final String details;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.bfTheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: t.danger.fg),
            const SizedBox(height: AppTheme.spacing16),
            Text(l10n.configErrorTitle, style: text.headlineMedium),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              l10n.configErrorHint,
              style: text.bodyMedium?.copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacing12),
            SelectableText(
              details,
              style: text.bodySmall?.copyWith(color: t.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
