import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/core/storage/secure_storage.dart';
import 'package:buildflow/core/storage/storage_providers.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/auth/presentation/screens/join_screen.dart';
import 'package:buildflow/features/team/data/fake_team_store.dart';
import 'package:buildflow/features/team/presentation/providers/fake_team_store_provider.dart';
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

  late FakeTeamStore store;

  Future<void> pumpJoin(WidgetTester tester) async {
    store = FakeTeamStore();
    await pumpTestApp(
      tester,
      const JoinScreen(),
      overrides: [
        secureStorageProvider.overrideWithValue(_MemoryStorage()),
        fakeTeamStoreProvider.overrideWithValue(store),
      ],
    );
  }

  Future<void> fillAndSubmit(WidgetTester tester, String code) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), code);
    await tester.enterText(fields.at(1), 'Новый Сотрудник');
    await tester.enterText(fields.at(2), 'new@company.kg');
    await tester.enterText(fields.at(3), '123456');
    await tester.tap(find.text(l10n.joinButton));
    await tester.pump(const Duration(seconds: 1));
  }

  AuthState authState(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(JoinScreen)))
          .read(authProvider);

  testWidgets('asks for the code before sending', (tester) async {
    await pumpJoin(tester);

    await fillAndSubmit(tester, '');

    expect(find.text(l10n.validationInviteCodeRequired), findsOneWidget);
    expect(authState(tester).user, isNull);
  });

  testWidgets('a wrong code says why and keeps the form', (tester) async {
    await pumpJoin(tester);

    await fillAndSubmit(tester, 'ZZZZZZ');

    expect(find.text(l10n.errorInvalidInviteCode), findsOneWidget);
    expect(find.text('Новый Сотрудник'), findsOneWidget);
    expect(authState(tester).user, isNull);
  });

  testWidgets('signs in with the role of the code', (tester) async {
    await pumpJoin(tester);
    final code =
        store.createInvite(companyId: 'company-1', role: UserRole.worker).code;

    // Typed the way it is dictated: lower case with a dash.
    final typed =
        '${code.substring(0, 3).toLowerCase()}-${code.substring(3)}';
    await fillAndSubmit(tester, typed);

    final auth = authState(tester);
    expect(auth.status, AuthStatus.authenticated);
    expect(auth.user?.role, UserRole.worker);
    expect(auth.user?.email, 'new@company.kg');
  });
}
