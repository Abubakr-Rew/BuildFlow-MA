import 'dart:async';

import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/app/router.dart';
import 'package:buildflow/app/routes.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/core/storage/secure_storage.dart';
import 'package:buildflow/core/storage/storage_providers.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/auth/presentation/role_label.dart';
import 'package:buildflow/features/projects/presentation/screens/project_detail_screen.dart';
import 'package:buildflow/features/reports/presentation/screens/report_detail_screen.dart';
import 'package:buildflow/features/team/presentation/screens/people_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// In-memory storage so FakeAuthRepository runs without platform channels.
class _MemoryStorage extends SecureStorageService {
  final Map<String, String> _store = {};

  @override
  Future<void> saveToken(String token) async => _store['token'] = token;

  @override
  Future<String?> readToken() async => _store['token'];

  @override
  Future<void> saveUserId(String id) async => _store['userId'] = id;

  @override
  Future<String?> readUserId() async => _store['userId'];

  @override
  Future<void> clearAll() async => _store.clear();
}

User _user(UserRole role) => User(
      id: 'u-${role.name}',
      email: '${role.name}@test.kg',
      name: role.name,
      role: role,
      companyId: 'c1',
    );

AuthState _signedIn(UserRole role) =>
    AuthState(status: AuthStatus.authenticated, user: _user(role));

const _signedOut = AuthState(status: AuthStatus.unauthenticated);

const _sections = {
  UserRole.owner: Routes.ownerTeam,
  UserRole.foreman: Routes.foremanNewReport,
  UserRole.worker: Routes.workerReports,
};

void main() {
  group('authRedirect', () {
    test('holds every path on splash while the session is restored', () {
      const restoring = AuthState();
      expect(authRedirect(restoring, Routes.splash), isNull);
      expect(authRedirect(restoring, Routes.login), Routes.splash);
      expect(authRedirect(restoring, Routes.ownerProjects), Routes.splash);
    });

    test('sends a signed-out user to login', () {
      expect(authRedirect(_signedOut, Routes.splash), Routes.login);
      expect(authRedirect(_signedOut, Routes.ownerProjects), Routes.login);
      expect(authRedirect(_signedOut, Routes.workerProfile), Routes.login);
      expect(authRedirect(_signedOut, Routes.project('project-1')), Routes.login);
      expect(authRedirect(_signedOut, Routes.report('report-1')), Routes.login);
    });

    test('lets a signed-out user stay on login, register and join', () {
      expect(authRedirect(_signedOut, Routes.login), isNull);
      expect(authRedirect(_signedOut, Routes.register), isNull);
      expect(authRedirect(_signedOut, Routes.join), isNull);
    });

    for (final role in UserRole.values) {
      group('signed in as ${role.name}', () {
        final auth = _signedIn(role);
        final home = Routes.homeFor(role);

        test('leaves splash, login, register and join for the role home', () {
          expect(authRedirect(auth, Routes.splash), home);
          expect(authRedirect(auth, Routes.login), home);
          expect(authRedirect(auth, Routes.register), home);
          expect(authRedirect(auth, Routes.join), home);
        });

        test('stays inside its own section', () {
          expect(authRedirect(auth, home), isNull);
          expect(authRedirect(auth, _sections[role]!), isNull);
        });

        test('is sent home from other roles sections', () {
          for (final other in UserRole.values.where((r) => r != role)) {
            expect(authRedirect(auth, Routes.homeFor(other)), home);
            expect(authRedirect(auth, _sections[other]!), home);
          }
        });

        test('can open project and report details', () {
          expect(authRedirect(auth, Routes.project('project-1')), isNull);
          expect(authRedirect(auth, Routes.report('report-1')), isNull);
        });

        test('can open people search', () {
          expect(authRedirect(auth, Routes.peopleSearch), isNull);
        });

        test('has its chats tab and opens a chat over the navigation', () {
          expect(authRedirect(auth, Routes.chatsFor(role)), isNull);
          expect(authRedirect(auth, Routes.chat('chat-project-1')), isNull);
          for (final other in UserRole.values.where((r) => r != role)) {
            expect(authRedirect(auth, Routes.chatsFor(other)), home);
          }
        });
      });
    }
  });

  group('routerProvider', () {
    late ProviderContainer container;
    late GoRouter router;

    String location() => router.routerDelegate.currentConfiguration.uri.path;

    // Lets the fake repositories' simulated latency (< 1s) elapse.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    Future<void> login(WidgetTester tester, String email) async {
      final done = container
          .read(authProvider.notifier)
          .login(email: email, password: '123456');
      await settle(tester);
      expect((await done).isSuccess, isTrue);
    }

    Future<void> logout(WidgetTester tester) async {
      final done = container.read(authProvider.notifier).logout();
      await settle(tester);
      await done;
    }

    Future<void> pumpApp(WidgetTester tester) async {
      // The Ahem test font renders every glyph as a full square, so rows
      // that fit on a device overflow in tests: use a wide surface and
      // shrink text (see textScaler below).
      tester.view
        ..physicalSize = const Size(1080, 2340)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(_MemoryStorage())],
      );
      router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(0.7)),
              child: child!,
            ),
          ),
        ),
      );
      await settle(tester);
    }

    // Unmount the app before the container (and the router) is disposed.
    // The requests the last screens started may still be waiting out their
    // random fake latency, and a timer left pending fails the test, so let
    // it run out first: each request waits under a second.
    Future<void> tearDownApp(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      container.dispose();
    }

    testWidgets('follows login, logout and login as another role', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(location(), Routes.login);

      await login(tester, 'owner@buildflow.kg');
      expect(location(), Routes.ownerProjects);

      await logout(tester);
      expect(location(), Routes.login);

      await login(tester, 'worker1@buildflow.kg');
      expect(location(), Routes.workerProjects);

      await logout(tester);
      await login(tester, 'foreman1@buildflow.kg');
      expect(location(), Routes.foremanProjects);

      // Auth changes refresh the same router instead of rebuilding it.
      expect(container.read(routerProvider), same(router));

      await tearDownApp(tester);
    });

    testWidgets('a worker invited by the director joins with the code', (
      tester,
    ) async {
      final l10n = AppLocalizationsRu();
      await pumpApp(tester);

      // The director creates a code for a worker on the team screen.
      await login(tester, 'owner@buildflow.kg');
      router.go(Routes.ownerTeam);
      await settle(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(UserRole.worker.label(l10n)),
        ),
      );
      await settle(tester);

      final codeText = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && RegExp(r'^[A-Z2-9]{6}$').hasMatch(w.data ?? ''),
        ),
      );
      final code = codeText.data!;
      await tester.tap(find.text(l10n.done));
      await settle(tester);

      await logout(tester);
      expect(location(), Routes.login);

      // The worker opens the join screen from login and enters the code.
      await tester.tap(find.text(l10n.haveInviteCode));
      await settle(tester);
      expect(location(), Routes.join);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), code.toLowerCase());
      await tester.enterText(fields.at(1), 'Азамат Новиков');
      await tester.enterText(fields.at(2), 'azamat@buildflow.kg');
      await tester.enterText(fields.at(3), '123456');
      await tester.tap(find.text(l10n.joinButton));
      await settle(tester);

      // The redirect, not the screen, opens the worker's home.
      expect(location(), Routes.workerProjects);
      expect(container.read(currentUserProvider)?.role, UserRole.worker);

      // The director now sees the new worker in the team.
      await logout(tester);
      await login(tester, 'owner@buildflow.kg');
      router.go(Routes.ownerTeam);
      await settle(tester);
      expect(find.text('Азамат Новиков'), findsOneWidget);

      await tearDownApp(tester);
    });

    testWidgets('opens project and report details on top of the shell', (
      tester,
    ) async {
      await pumpApp(tester);
      await login(tester, 'owner@buildflow.kg');

      unawaited(router.push(Routes.project('project-1')));
      await settle(tester);
      expect(find.byType(ProjectDetailScreen), findsOneWidget);

      unawaited(router.push(Routes.report('report-1')));
      await settle(tester);
      expect(find.byType(ReportDetailScreen), findsOneWidget);

      await tearDownApp(tester);
    });

    testWidgets('opens people search from the team tab or the projects', (
      tester,
    ) async {
      final l10n = AppLocalizationsRu();
      await pumpApp(tester);

      Future<void> openSearch() async {
        await tester.tap(find.byTooltip(l10n.searchPeople));
        await settle(tester);
        expect(find.byType(PeopleSearchScreen), findsOneWidget);
        router.pop();
        await settle(tester);
      }

      // Directors have a team tab with the search in its header.
      await login(tester, 'owner@buildflow.kg');
      router.go(Routes.ownerTeam);
      await settle(tester);
      await openSearch();
      expect(location(), Routes.ownerTeam);
      await logout(tester);

      // Foremen and workers don't: theirs is in the projects header.
      for (final email in ['foreman1@buildflow.kg', 'worker1@buildflow.kg']) {
        await login(tester, email);
        await openSearch();
        await logout(tester);
      }

      await tearDownApp(tester);
    });
  });
}
