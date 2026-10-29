import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/routes.dart';
import 'package:buildflow/core/photos/lost_capture.dart';
import 'package:buildflow/core/photos/photo_providers.dart';
import 'package:buildflow/core/widgets/bf_bottom_nav.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/auth/presentation/screens/join_screen.dart';
import 'package:buildflow/features/auth/presentation/screens/login_screen.dart';
import 'package:buildflow/features/auth/presentation/screens/register_screen.dart';
import 'package:buildflow/features/auth/presentation/screens/splash_screen.dart';
import 'package:buildflow/features/chat/presentation/providers/chat_provider.dart';
import 'package:buildflow/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:buildflow/features/chat/presentation/screens/chat_screen.dart';
import 'package:buildflow/features/profile/presentation/screens/profile_screen.dart';
import 'package:buildflow/features/projects/presentation/screens/project_detail_screen.dart';
import 'package:buildflow/features/projects/presentation/screens/project_list_screen.dart';
import 'package:buildflow/features/reports/presentation/screens/new_report_screen.dart';
import 'package:buildflow/features/reports/presentation/screens/report_detail_screen.dart';
import 'package:buildflow/features/reports/presentation/screens/report_list_screen.dart';
import 'package:buildflow/features/team/presentation/screens/people_search_screen.dart';
import 'package:buildflow/features/team/presentation/screens/team_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

const _rolePrefixes = ['/owner', '/foreman', '/worker'];

/// Where to send the user who is opening [path], or `null` to let them stay.
///
/// Pure function of the auth state so it can be unit-tested; the router's
/// `redirect` calls it with the current [AuthState].
String? authRedirect(AuthState auth, String path) {
  final isSplash = path == Routes.splash;

  // Session restore still running: hold everything on the splash screen.
  if (auth.status == AuthStatus.initial) {
    return isSplash ? null : Routes.splash;
  }

  final user = auth.user;
  final isAuthPage =
      path == Routes.login || path == Routes.register || path == Routes.join;
  if (user == null) return isAuthPage ? null : Routes.login;
  if (isSplash || isAuthPage) return Routes.homeFor(user.role);

  // Keep each role inside its own section.
  final ownPrefix = Routes.prefixFor(user.role);
  final isOtherRoleSection =
      _rolePrefixes.any((p) => p != ownPrefix && path.startsWith(p));
  if (isOtherRoleSection) return Routes.homeFor(user.role);

  return null;
}

/// The app router. Built once; auth changes re-run [authRedirect] through
/// `refreshListenable` instead of recreating the router.
final routerProvider = Provider<GoRouter>((ref) {
  // Fires only when the session status or the user changes, not on
  // isLoading / failure updates.
  final initial = ref.read(authProvider);
  final authChanges =
      ValueNotifier<(AuthStatus, User?)>((initial.status, initial.user));
  ref.listen<(AuthStatus, User?)>(
    authProvider.select((s) => (s.status, s.user)),
    (_, next) => authChanges.value = next,
  );

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: authChanges,
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
      GoRoute(
        path: Routes.join,
        builder: (_, __) => const JoinScreen(),
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
      GoRoute(
        path: Routes.peopleSearch,
        builder: (_, __) => const PeopleSearchScreen(),
      ),
      GoRoute(
        path: Routes.chatDetail,
        builder: (_, state) =>
            ChatScreen(chatId: state.pathParameters['id']!),
      ),

      // Director shell: Объекты · Команда · Чаты · Отчёты · Профиль
      _shell(_ShellRole.owner, [
        (Routes.ownerProjects, const ProjectListScreen()),
        (Routes.ownerTeam, const TeamListScreen()),
        (Routes.ownerChats, const ChatListScreen()),
        (Routes.ownerReports, const ReportListScreen()),
        (Routes.ownerProfile, const ProfileScreen()),
      ]),

      // Foreman shell: Объекты · Чаты · Отчёт · История · Профиль
      _shell(_ShellRole.foreman, [
        (Routes.foremanProjects, const ProjectListScreen()),
        (Routes.foremanChats, const ChatListScreen()),
        (Routes.foremanNewReport, const NewReportScreen()),
        (Routes.foremanReports, const ReportListScreen()),
        (Routes.foremanProfile, const ProfileScreen()),
      ]),

      // Worker shell: Объекты · Чаты · Отчёты · Профиль
      _shell(_ShellRole.worker, [
        (Routes.workerProjects, const ProjectListScreen()),
        (Routes.workerChats, const ChatListScreen()),
        (Routes.workerReports, const ReportListScreen()),
        (Routes.workerProfile, const ProfileScreen()),
      ]),
    ],
    redirect: (context, state) =>
        authRedirect(ref.read(authProvider), state.uri.path),
  );

  ref.onDispose(() {
    router.dispose();
    authChanges.dispose();
  });
  return router;
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

    final projects = BfNavItem(
      icon: Icons.construction_outlined,
      selectedIcon: Icons.construction,
      label: l10n.navProjects,
    );
    final reports = BfNavItem(
      icon: Icons.article_outlined,
      selectedIcon: Icons.article,
      label: l10n.navReports,
    );
    final profile = BfNavItem(
      icon: Icons.person_outlined,
      selectedIcon: Icons.person,
      label: l10n.navProfile,
    );
    final chats = BfNavItem(
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      label: l10n.navChats,
      badgeCount: ref.watch(totalUnreadProvider),
    );

    final destinations = switch (role) {
      _ShellRole.owner => [
          projects,
          BfNavItem(
            icon: Icons.group_outlined,
            selectedIcon: Icons.group,
            label: l10n.navTeam,
          ),
          chats,
          reports,
          profile,
        ],
      _ShellRole.foreman => [
          projects,
          chats,
          BfNavItem(
            icon: Icons.photo_camera_outlined,
            selectedIcon: Icons.photo_camera_rounded,
            label: l10n.navNewReport,
            prominent: true,
          ),
          BfNavItem(
            icon: Icons.history_rounded,
            selectedIcon: Icons.history_rounded,
            label: l10n.navHistory,
          ),
          profile,
        ],
      _ShellRole.worker => [projects, chats, reports, profile],
    };

    return Scaffold(
      body: _LostCaptureOpener(role: role, child: shell),
      bottomNavigationBar: BfBottomNav(
        selectedIndex: shell.currentIndex,
        onSelected: (i) => shell.goBranch(
          i,
          initialLocation: i == shell.currentIndex,
        ),
        items: destinations,
      ),
    );
  }
}

/// Opens the screen a camera shot was for when the shot came back after
/// Android killed the app under the camera: the chat, or the new report.
/// The screen then takes the shot into its photos.
class _LostCaptureOpener extends ConsumerStatefulWidget {
  const _LostCaptureOpener({required this.role, required this.child});

  final _ShellRole role;
  final Widget child;

  @override
  ConsumerState<_LostCaptureOpener> createState() => _LostCaptureOpenerState();
}

class _LostCaptureOpenerState extends ConsumerState<_LostCaptureOpener> {
  @override
  void initState() {
    super.initState();
    ref.listenManual<LostCapture?>(
      lostCaptureProvider,
      (_, capture) {
        if (capture == null) return;
        // Navigation and provider changes wait for the frame to finish.
        WidgetsBinding.instance.addPostFrameCallback((_) => _open(capture));
      },
      fireImmediately: true,
    );
  }

  void _open(LostCapture capture) {
    if (!mounted || ref.read(lostCaptureProvider) != capture) return;
    final target = capture.target;
    if (target.userId != ref.read(currentUserProvider)?.id) {
      ref.read(lostCaptureProvider.notifier).discard();
      return;
    }
    switch (target.kind) {
      case CaptureKind.chat:
        context.push(Routes.chat(target.id!));
      case CaptureKind.report when widget.role == _ShellRole.foreman:
        context.go(Routes.foremanNewReport);
      case CaptureKind.report:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => NewReportScreen(initialProjectId: target.id),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
