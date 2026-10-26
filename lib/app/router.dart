import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/routes.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/auth/presentation/screens/login_screen.dart';
import 'package:buildflow/features/auth/presentation/screens/register_screen.dart';
import 'package:buildflow/features/auth/presentation/screens/splash_screen.dart';
import 'package:buildflow/features/profile/presentation/screens/profile_screen.dart';
import 'package:buildflow/features/projects/presentation/screens/project_detail_screen.dart';
import 'package:buildflow/features/projects/presentation/screens/project_list_screen.dart';
import 'package:buildflow/features/reports/presentation/screens/new_report_screen.dart';
import 'package:buildflow/features/reports/presentation/screens/report_detail_screen.dart';
import 'package:buildflow/features/reports/presentation/screens/report_list_screen.dart';
import 'package:buildflow/features/team/presentation/screens/team_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

const _rolePrefixes = ['/owner', '/foreman', '/worker'];

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

      // Shared detail screens
      GoRoute(
        path: Routes.projectDetail,
        builder: (_, state) =>
            ProjectDetailScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.reportDetail,
        builder: (_, state) =>
            ReportDetailScreen(reportId: state.pathParameters['id']!),
      ),

      // Director shell
      _shell(_ShellRole.owner, [
        (Routes.ownerProjects, const ProjectListScreen()),
        (Routes.ownerTeam, const TeamListScreen()),
        (Routes.ownerReports, const ReportListScreen()),
        (Routes.ownerProfile, const ProfileScreen()),
      ]),

      // Foreman shell
      _shell(_ShellRole.foreman, [
        (Routes.foremanProjects, const ProjectListScreen()),
        (Routes.foremanNewReport, const NewReportScreen()),
        (Routes.foremanReports, const ReportListScreen()),
        (Routes.foremanProfile, const ProfileScreen()),
      ]),

      // Worker shell
      _shell(_ShellRole.worker, [
        (Routes.workerProjects, const ProjectListScreen()),
        (Routes.workerReports, const ReportListScreen()),
        (Routes.workerProfile, const ProfileScreen()),
      ]),
    ],
    redirect: (context, state) {
      final user = ref.read(authProvider).user;
      final path = state.uri.path;

      if (path == Routes.splash) return null;

      final isAuthPage = path == Routes.login || path == Routes.register;
      if (user == null) return isAuthPage ? null : Routes.login;
      if (isAuthPage) return Routes.homeFor(user.role);

      // Keep each role inside its own section.
      final ownPrefix = Routes.prefixFor(user.role);
      final isOtherRoleSection = _rolePrefixes
          .any((p) => p != ownPrefix && path.startsWith(p));
      if (isOtherRoleSection) return Routes.homeFor(user.role);

      return null;
    },
  );
});

StatefulShellRoute _shell(
  _ShellRole role,
  List<(String, Widget)> tabs,
) {
  return StatefulShellRoute.indexedStack(
    builder: (context, state, shell) => _RoleShell(role: role, shell: shell),
    branches: [
      for (final (path, screen) in tabs)
        StatefulShellBranch(
          routes: [GoRoute(path: path, builder: (_, __) => screen)],
        ),
    ],
  );
}

// ── Shell scaffold with bottom navigation ─────────────────────

enum _ShellRole { owner, foreman, worker }

class _RoleShell extends ConsumerWidget {
  const _RoleShell({required this.role, required this.shell});

  final _ShellRole role;
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    final projects = NavigationDestination(
      icon: const Icon(Icons.construction_outlined),
      selectedIcon: const Icon(Icons.construction),
      label: l10n.navProjects,
    );
    final reports = NavigationDestination(
      icon: const Icon(Icons.article_outlined),
      selectedIcon: const Icon(Icons.article),
      label: l10n.navReports,
    );
    final profile = NavigationDestination(
      icon: const Icon(Icons.person_outlined),
      selectedIcon: const Icon(Icons.person),
      label: l10n.navProfile,
    );

    final destinations = switch (role) {
      _ShellRole.owner => [
          projects,
          NavigationDestination(
            icon: const Icon(Icons.group_outlined),
            selectedIcon: const Icon(Icons.group),
            label: l10n.navTeam,
          ),
          reports,
          profile,
        ],
      _ShellRole.foreman => [
          projects,
          NavigationDestination(
            icon: const Icon(Icons.add_a_photo_outlined),
            selectedIcon: const Icon(Icons.add_a_photo),
            label: l10n.navNewReport,
          ),
          reports,
          profile,
        ],
      _ShellRole.worker => [projects, reports, profile],
    };

    return Scaffold(
      body: shell,
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
