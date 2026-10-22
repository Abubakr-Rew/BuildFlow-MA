import 'dart:math';

import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/storage/secure_storage.dart';
import 'package:buildflow/features/auth/domain/entities/company.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/domain/repositories/auth_repository.dart';

/// In-memory fake auth repository with seeded demo data.
/// Simulates 300-800ms latency and occasional failures.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    required this.secureStorage,
    this.simulateFailures = false,
  });

  final SecureStorageService secureStorage;
  final bool simulateFailures;

  final _random = Random();
  User? _currentUser;

  // ── Seeded data ──────────────────────────────────────────
  static const _companyId = 'company-1';

  static const _company = Company(id: _companyId, name: 'СтройБишкек');

  final Map<String, FakeUserRecord> _users = {
    'owner@buildflow.kg': const FakeUserRecord(
      user: User(
        id: 'user-owner-1',
        email: 'owner@buildflow.kg',
        name: 'Асан Бекович',
        role: UserRole.owner,
        companyId: _companyId,
      ),
      password: '123456',
    ),
    'foreman1@buildflow.kg': const FakeUserRecord(
      user: User(
        id: 'user-foreman-1',
        email: 'foreman1@buildflow.kg',
        name: 'Бакыт Касымов',
        role: UserRole.foreman,
        companyId: _companyId,
      ),
      password: '123456',
    ),
    'foreman2@buildflow.kg': const FakeUserRecord(
      user: User(
        id: 'user-foreman-2',
        email: 'foreman2@buildflow.kg',
        name: 'Данияр Жумабеков',
        role: UserRole.foreman,
        companyId: _companyId,
      ),
      password: '123456',
    ),
  };

  Company get company => _company;
  Map<String, FakeUserRecord> get users => _users;

  @override
  User? get currentUser => _currentUser;

  Future<void> _simulateLatency() async {
    final ms = 300 + _random.nextInt(500);
    await Future<void>.delayed(Duration(milliseconds: ms));
  }

  bool _shouldFail() {
    if (!simulateFailures) return false;
    return _random.nextInt(5) == 0; // 20% failure rate
  }

  @override
  Future<Result<User>> login({
    required String email,
    required String password,
  }) async {
    await _simulateLatency();
    if (_shouldFail()) {
      return const Err(NetworkFailure(message: 'Simulated network error'));
    }

    final record = _users[email.trim().toLowerCase()];
    if (record == null || record.password != password) {
      return const Err(AuthFailure(message: 'Неверный email или пароль'));
    }

    _currentUser = record.user;
    await secureStorage.saveToken('fake-token-${record.user.id}');
    await secureStorage.saveUserId(record.user.id);
    return Success(record.user);
  }

  @override
  Future<Result<User>> register({
    required String email,
    required String password,
    required String name,
    required String companyName,
  }) async {
    await _simulateLatency();
    if (_shouldFail()) {
      return const Err(NetworkFailure(message: 'Simulated network error'));
    }

    final lowerEmail = email.trim().toLowerCase();
    if (_users.containsKey(lowerEmail)) {
      return const Err(
        AuthFailure(message: 'Пользователь с таким email уже существует'),
      );
    }

    final userId = 'user-${DateTime.now().millisecondsSinceEpoch}';
    final newCompanyId = 'company-${DateTime.now().millisecondsSinceEpoch}';
    final user = User(
      id: userId,
      email: lowerEmail,
      name: name.trim(),
      role: UserRole.owner,
      companyId: newCompanyId,
    );

    _users[lowerEmail] = FakeUserRecord(user: user, password: password);
    _currentUser = user;
    await secureStorage.saveToken('fake-token-$userId');
    await secureStorage.saveUserId(userId);
    return Success(user);
  }

  @override
  Future<Result<User>> joinWithInviteCode({
    required String email,
    required String password,
    required String name,
    required String inviteCode,
  }) async {
    await _simulateLatency();
    if (inviteCode.length < 6) {
      return const Err(
        ValidationFailure(message: 'Неверный код приглашения'),
      );
    }

    final lowerEmail = email.trim().toLowerCase();
    final userId = 'user-${DateTime.now().millisecondsSinceEpoch}';
    final user = User(
      id: userId,
      email: lowerEmail,
      name: name.trim(),
      role: UserRole.foreman,
      companyId: _companyId,
    );

    _users[lowerEmail] = FakeUserRecord(user: user, password: password);
    _currentUser = user;
    await secureStorage.saveToken('fake-token-$userId');
    await secureStorage.saveUserId(userId);
    return Success(user);
  }

  @override
  Future<Result<User>> restoreSession() async {
    await _simulateLatency();

    try {
      final userId = await secureStorage
          .readUserId()
          .timeout(const Duration(seconds: 5));
      if (userId == null) {
        return const Err(AuthFailure(message: 'No session'));
      }

      for (final record in _users.values) {
        if (record.user.id == userId) {
          _currentUser = record.user;
          return Success(record.user);
        }
      }

      return const Err(AuthFailure(message: 'Session expired'));
    } catch (e) {
      // Timeout or flutter_secure_storage error — clear corrupted storage
      try {
        await secureStorage.clearAll().timeout(const Duration(seconds: 2));
      } catch (_) {
        // Ignore — storage may be completely broken
      }
      return const Err(
        AuthFailure(message: 'Failed to read session, please log in again'),
      );
    }
  }

  @override
  Future<Result<void>> logout() async {
    await _simulateLatency();
    _currentUser = null;
    await secureStorage.clearAll();
    return const Success(null);
  }
}

/// Record holder for fake user data.
class FakeUserRecord {
  const FakeUserRecord({required this.user, required this.password});

  final User user;
  final String password;
}
