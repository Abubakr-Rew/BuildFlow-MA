import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/storage/secure_storage.dart';
import 'package:buildflow/features/auth/data/fake_auth_repository.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/team/data/fake_team_repository.dart';
import 'package:buildflow/features/team/data/fake_team_store.dart';
import 'package:flutter_test/flutter_test.dart';

// Minimal stub so tests run without platform channels.
class FakeSecureStorage extends SecureStorageService {
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

void main() {
  late FakeAuthRepository repo;
  late FakeSecureStorage storage;
  late FakeTeamStore teamStore;

  setUp(() {
    storage = FakeSecureStorage();
    teamStore = FakeTeamStore();
    repo = FakeAuthRepository(secureStorage: storage, teamStore: teamStore);
  });

  group('FakeAuthRepository', () {
    test('login succeeds with valid credentials', () async {
      final result = await repo.login(
        email: 'owner@buildflow.kg',
        password: '123456',
      );
      expect(result.isSuccess, isTrue);
      expect(result.value.email, 'owner@buildflow.kg');
      expect(repo.currentUser, isNotNull);
    });

    test('login fails with wrong password', () async {
      final result = await repo.login(
        email: 'owner@buildflow.kg',
        password: 'wrong',
      );
      expect(result.failure.code, FailureCode.invalidCredentials);
      expect(repo.currentUser, isNull);
    });

    test('login fails with unknown email', () async {
      final result = await repo.login(
        email: 'unknown@test.com',
        password: '123456',
      );
      expect(result.failure.code, FailureCode.invalidCredentials);
    });

    test('register creates a new owner account', () async {
      final result = await repo.register(
        email: 'new@company.kg',
        password: 'secret123',
        name: 'Тест',
        companyName: 'Тестовая компания',
      );
      expect(result.isSuccess, isTrue);
      expect(result.value.name, 'Тест');
      expect(repo.currentUser, isNotNull);
    });

    test('register fails for duplicate email', () async {
      final result = await repo.register(
        email: 'owner@buildflow.kg',
        password: '123456',
        name: 'Dupe',
        companyName: 'Dupe Co',
      );
      expect(result.failure.code, FailureCode.emailTaken);
    });

    test('logout clears user and storage', () async {
      await repo.login(email: 'owner@buildflow.kg', password: '123456');
      expect(repo.currentUser, isNotNull);

      await repo.logout();
      expect(repo.currentUser, isNull);
      expect(await storage.readToken(), isNull);
    });

    test('restoreSession restores from storage', () async {
      // Login first to populate storage
      await repo.login(email: 'owner@buildflow.kg', password: '123456');

      // Create a new repo instance with same storage
      final repo2 =
          FakeAuthRepository(secureStorage: storage, teamStore: teamStore);
      final result = await repo2.restoreSession();
      expect(result.isSuccess, isTrue);
      expect(result.value.email, 'owner@buildflow.kg');
    });

    test('restoreSession fails without prior login', () async {
      final result = await repo.restoreSession();
      expect(result.failure.code, FailureCode.sessionExpired);
    });

    test('failure messages are for logs, not Russian UI text', () async {
      final result = await repo.login(
        email: 'owner@buildflow.kg',
        password: 'wrong',
      );
      expect(result.failure.message, isNot(matches(RegExp('[А-Яа-яЁё]'))));
    });
  });

  group('FakeAuthRepository.joinWithInviteCode', () {
    Future<Result<User>> join(
      String code, {
      String email = 'new@company.kg',
    }) =>
        repo.joinWithInviteCode(
          email: email,
          password: '123456',
          name: 'Новый Сотрудник',
          inviteCode: code,
        );

    String invite(UserRole role) =>
        teamStore.createInvite(companyId: 'company-1', role: role).code;

    test('takes the role and the company from the code', () async {
      for (final (role, email) in [
        (UserRole.worker, 'w@company.kg'),
        (UserRole.foreman, 'f@company.kg'),
      ]) {
        final result = await join(invite(role), email: email);
        expect(result.value.role, role);
        expect(result.value.companyId, 'company-1');
        expect(repo.currentUser, result.value);
      }
    });

    test('a code works only once', () async {
      final code = invite(UserRole.worker);
      expect((await join(code)).isSuccess, isTrue);

      final again = await join(code, email: 'other@company.kg');
      expect(again.failure.code, FailureCode.invalidInviteCode);
    });

    test('rejects an unknown code', () async {
      final result = await join('ZZZZZZ');
      expect(result.failure.code, FailureCode.invalidInviteCode);
      expect(repo.currentUser, isNull);
    });

    test('rejects an expired code', () async {
      var now = DateTime(2026, 10, 28);
      teamStore = FakeTeamStore(now: () => now);
      repo = FakeAuthRepository(secureStorage: storage, teamStore: teamStore);
      final code = invite(UserRole.worker);

      now = now.add(const Duration(days: 8));
      expect((await join(code)).failure.code, FailureCode.invalidInviteCode);
    });

    test('accepts a code typed with spaces, dashes and lower case', () async {
      final code = invite(UserRole.foreman);
      final typed = ' ${code.substring(0, 3).toLowerCase()}-'
          '${code.substring(3)} ';
      expect((await join(typed)).value.role, UserRole.foreman);
    });

    test('a taken email keeps the code valid', () async {
      final code = invite(UserRole.worker);
      final taken = await join(code, email: 'worker1@buildflow.kg');
      expect(taken.failure.code, FailureCode.emailTaken);

      expect((await join(code)).isSuccess, isTrue);
    });

    test('the new member shows up in the team and can log in', () async {
      final user = (await join(invite(UserRole.worker))).value;

      final team = FakeTeamRepository(store: teamStore);
      final member = (await team.getMembers())
          .value
          .where((m) => m.userId == user.id)
          .single;
      expect(member.role, UserRole.worker);
      expect(member.email, 'new@company.kg');

      await repo.logout();
      final login =
          await repo.login(email: 'new@company.kg', password: '123456');
      expect(login.value.id, user.id);
    });
  });
}
