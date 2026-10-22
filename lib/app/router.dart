import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/routes.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/auth/presentation/screens/login_screen.dart';
import 'package:buildflow/features/auth/presentation/screens/register_screen.dart';
import 'package:buildflow/features/auth/presentation/screens/splash_screen.dart';
import 'package:buildflow/features/profile/presentation/screens/profile_screen.dart';
import 'package:buildflow/features/projects/presentation/screens/project_list_screen.dart';
import 'package:buildflow/features/reports/presentation/screens/new_report_screen.dart';
import 'package:buildflow/features/reports/presentation/screens/report_list_screen.dart';
import 'package:buildflow/features/team/presentation/screens/team_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.splash,
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (_, __) => const RegisterScreen(),
      ),

      // Owner shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, child) =>
            _RoleShell(role: _ShellRole.owner, child: child),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.ownerProjects,
                builder: (_, __) => const ProjectListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.ownerTeam,
                builder: (_, __) => const TeamListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.ownerReports,
                builder: (_, __) => const ReportListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.ownerProfile,
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Foreman shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, child) =>
            _RoleShell(role: _ShellRole.foreman, child: child),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.foremanProjects,
                builder: (_, __) =>
                    const ProjectListScreen(isOwner: false),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.foremanNewReport,
                builder: (_, __) => const NewReportScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.foremanProfile,
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final isAuth = auth.isAuthenticated;
      final path = state.uri.path;

      if (path == Routes.splash) return null;

      if (!isAuth && path != Routes.login && path != Routes.register) {
        return Routes.login;
      }

      if (isAuth && (path == Routes.login || path == Routes.register)) {
        return auth.isOwner ? Routes.ownerProjects : Routes.foremanProjects;
      }

      if (isAuth && auth.isForeman && path.startsWith('/owner')) {
        return Routes.foremanProjects;
      }
      if (isAuth && auth.isOwner && path.startsWith('/foreman')) {
        return Routes.ownerProjects;
      }

      return null;
    },
  );
});

// ── Shell scaffold with bottom navigation ─────────────────────

enum _ShellRole { owner, foreman }

class _RoleShell extends ConsumerWidget {
  const _RoleShell({required this.role, required this.child});

  final _ShellRole role;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final shell = StatefulNavigationShell.of(context);

    final destinations = switch (role) {
      _ShellRole.owner => [
          NavigationDestination(
            icon: const Icon(Icons.construction_outlined),
            selectedIcon: const Icon(Icons.construction),
            label: l10n.navProjects,
          ),
          NavigationDestination(
            icon: const Icon(Icons.group_outlined),
            selectedIcon: const Icon(Icons.group),
            label: l10n.navTeam,
          ),
          NavigationDestination(
            icon: const Icon(Icons.article_outlined),
            selectedIcon: const Icon(Icons.article),
            label: l10n.navReports,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outlined),
            selectedIcon: const Icon(Icons.person),
            label: l10n.navProfile,
          ),
        ],
      _ShellRole.foreman => [
          NavigationDestination(
            icon: const Icon(Icons.construction_outlined),
            selectedIcon: const Icon(Icons.construction),
            label: l10n.navProjects,
          ),
          NavigationDestination(
            icon: const Icon(Icons.add_a_photo_outlined),
            selectedIcon: const Icon(Icons.add_a_photo),
            label: l10n.navNewReport,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outlined),
            selectedIcon: const Icon(Icons.person),
            label: l10n.navProfile,
          ),
        ],
    };

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(
          i,
          initialLocation: i == shell.currentIndex,
        ),
        destinations: destinations,
      ),
    );
  }
}
