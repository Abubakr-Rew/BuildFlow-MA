import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/core/config.dart';
import 'package:buildflow/core/storage/secure_storage.dart';
import 'package:buildflow/core/widgets/bf_button.dart';
import 'package:buildflow/core/widgets/bf_chip.dart';
import 'package:buildflow/features/auth/data/fake_auth_repository.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/auth/presentation/screens/login_screen.dart';
import 'package:buildflow/features/team/data/fake_team_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/test_app.dart';

// In-memory storage so FakeAuthRepository runs without platform channels.
class _MemoryStorage extends SecureStorageService {
  final Map<String, String> _store = {};

  @override
  Future<void> saveToken(String token) async => _store['token'] = token;

  @override
  Future<void> saveUserId(String id) async => _store['userId'] = id;

  @override
  Future<String?> readUserId() async => _store['userId'];

  @override
  Future<void> clearAll() async => _store.clear();
}

void main() {
  final l10n = AppLocalizationsRu();

  /// The login screen over a fake sign-in, whatever the build's backend;
  /// [demo] overrides whether the demo sign-ins are on.
  Future<void> pumpLogin(WidgetTester tester, {bool? demo}) => pumpTestApp(
        tester,
        const LoginScreen(),
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(
              secureStorage: _MemoryStorage(),
              teamStore: FakeTeamStore(),
            ),
          ),
          if (demo != null) demoLoginEnabledProvider.overrideWithValue(demo),
        ],
      );

  AuthState authState(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(LoginScreen)))
          .read(authProvider);

  group('demoLoginEnabled', () {
    test('is on with the fake backend, in any build', () {
      expect(demoLoginEnabled(Backend.fake), isTrue);
    });

    test('is off with Supabase, in any build', () {
      expect(demoLoginEnabled(Backend.supabase), isFalse);
    });
  });

  testWidgets('with Supabase there are no demo sign-ins at all',
      (tester) async {
    await pumpLogin(tester, demo: false);

    expect(find.byType(BfChip), findsNothing);
    expect(find.text(l10n.quickLogin), findsNothing);
    expect(find.textContaining('@buildflow.kg'), findsNothing);
    expect(find.textContaining('123456'), findsNothing);
  });

  testWidgets('with Supabase the usual sign-in still works', (tester) async {
    await pumpLogin(tester, demo: false);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'owner@buildflow.kg');
    await tester.enterText(fields.at(1), '123456');
    await tester.tap(find.byType(BfButton));
    await tester.pump(const Duration(seconds: 1));

    expect(authState(tester).user?.email, 'owner@buildflow.kg');
  });

  testWidgets('in the demo a chip signs in as that role', (tester) async {
    await pumpLogin(tester, demo: true);

    expect(find.text(l10n.quickLogin), findsOneWidget);
    expect(find.byType(BfChip), findsNWidgets(3));
    expect(find.textContaining('123456'), findsOneWidget);

    await tester.tap(find.byType(BfChip).first);
    await tester.pump(const Duration(seconds: 1));

    expect(authState(tester).user?.email, 'owner@buildflow.kg');
  });

  // Run with --dart-define=BACKEND=supabase it checks the real wiring.
  testWidgets('by default it follows the backend of the build', (tester) async {
    await pumpLogin(tester);

    expect(
      find.byType(BfChip),
      kBackend == Backend.fake ? findsNWidgets(3) : findsNothing,
    );
  });
}
