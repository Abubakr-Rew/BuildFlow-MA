import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/router.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root MaterialApp widget.
class BuildFlowApp extends StatelessWidget {
  const BuildFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: _BuildFlowAppInner(),
    );
  }
}

class _BuildFlowAppInner extends ConsumerWidget {
  const _BuildFlowAppInner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'BuildFlow',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,

      // Localization
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      // Routing
      routerConfig: router,
    );
  }
}
