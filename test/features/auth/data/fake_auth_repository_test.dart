import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/storage/secure_storage.dart';
import 'package:buildflow/features/auth/data/fake_auth_repository.dart';
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

  setUp(() {
    storage = FakeSecureStorage();
    repo = FakeAuthRepository(secureStorage: storage);
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

    test('joinWithInviteCode rejects an invalid code', () async {
      final result = await repo.joinWithInviteCode(
        email: 'new@company.kg',
        password: '123456',
        name: 'Foreman',
        inviteCode: 'ABC',
      );
      expect(result.failure.code, FailureCode.invalidInviteCode);
      expect(repo.currentUser, isNull);
    });

    test('joinWithInviteCode signs in with a valid code', () async {
      final result = await repo.joinWithInviteCode(
        email: 'new@company.kg',
        password: '123456',
        name: 'Foreman',
        inviteCode: 'ABC123',
      );
      expect(result.isSuccess, isTrue);
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
      final repo2 = FakeAuthRepository(secureStorage: storage);
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
}
