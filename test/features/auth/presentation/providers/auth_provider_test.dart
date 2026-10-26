import 'dart:async';

import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/domain/repositories/auth_repository.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = User(
  id: 'u-1',
  email: 'owner@test.kg',
  name: 'Owner',
  role: UserRole.owner,
  companyId: 'c-1',
);

// Answers every call with [result] (or throws [error]) once [gate] opens.
class _StubAuthRepository implements AuthRepository {
  Result<User> result = const Success(_user);
  Exception? error;
  Completer<void>? gate;

  Future<Result<User>> _respond() async {
    await gate?.future;
    if (error != null) throw error!;
    return result;
  }

  @override
  User? get currentUser => null;

  @override
  Future<Result<User>> login({
    required String email,
    required String password,
  }) =>
      _respond();

  @override
  Future<Result<User>> register({
    required String email,
    required String password,
    required String name,
    required String companyName,
  }) =>
      _respond();

  @override
  Future<Result<User>> joinWithInviteCode({
    required String email,
    required String password,
    required String name,
    required String inviteCode,
  }) =>
      _respond();

  @override
  Future<Result<User>> restoreSession() => _respond();

  @override
  Future<Result<void>> logout() async => const Success(null);
}

void main() {
  late _StubAuthRepository repo;
  late ProviderContainer container;

  AuthState state() => container.read(authProvider);
  AuthNotifier notifier() => container.read(authProvider.notifier);

  setUp(() {
    repo = _StubAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  group('AuthNotifier', () {
    test('starts in the initial status without a user', () {
      expect(state().status, AuthStatus.initial);
      expect(state().user, isNull);
      expect(state().isLoading, isFalse);
    });

    test('restoreSession signs the stored user in', () async {
      await notifier().restoreSession();
      expect(state().status, AuthStatus.authenticated);
      expect(state().user, _user);
    });

    test('restoreSession without a session signs out', () async {
      repo.result = const Err(Failure(FailureCode.sessionExpired));
      await notifier().restoreSession();
      expect(state().status, AuthStatus.unauthenticated);
      expect(state().user, isNull);
    });

    test('login shows loading, then signs in', () async {
      repo.gate = Completer<void>();
      final done = notifier().login(email: 'a@b.kg', password: '123456');
      expect(state().isLoading, isTrue);

      repo.gate!.complete();
      expect(await done, isTrue);
      expect(state().status, AuthStatus.authenticated);
      expect(state().user, _user);
      expect(state().isLoading, isFalse);
      expect(state().failure, isNull);
    });

    test('failed login keeps the user signed out with the failure', () async {
      notifier().forceUnauthenticated();
      repo.result = const Err(Failure(FailureCode.invalidCredentials));

      expect(await notifier().login(email: 'a@b.kg', password: 'x'), isFalse);
      expect(state().status, AuthStatus.unauthenticated);
      expect(state().isLoading, isFalse);
      expect(state().failure?.code, FailureCode.invalidCredentials);
    });

    test('an exception from the repository becomes an unknown failure', () async {
      repo.error = Exception('boom');
      expect(await notifier().login(email: 'a@b.kg', password: 'x'), isFalse);
      expect(state().isLoading, isFalse);
      expect(state().failure?.code, FailureCode.unknown);
    });

    test('the next attempt clears the previous failure', () async {
      repo.result = const Err(Failure(FailureCode.network));
      await notifier().login(email: 'a@b.kg', password: 'x');

      repo
        ..result = const Success(_user)
        ..gate = Completer<void>();
      final done = notifier().login(email: 'a@b.kg', password: '123456');
      expect(state().failure, isNull);
      repo.gate!.complete();
      await done;
    });

    test('register signs the new owner in', () async {
      final ok = await notifier().register(
        email: 'a@b.kg',
        password: '123456',
        name: 'Owner',
        companyName: 'Co',
      );
      expect(ok, isTrue);
      expect(state().status, AuthStatus.authenticated);
    });

    test('logout signs out', () async {
      await notifier().login(email: 'a@b.kg', password: '123456');
      await notifier().logout();
      expect(state().status, AuthStatus.unauthenticated);
      expect(state().user, isNull);
    });

    test('currentUserProvider follows the signed-in user', () async {
      expect(container.read(currentUserProvider), isNull);
      await notifier().login(email: 'a@b.kg', password: '123456');
      expect(container.read(currentUserProvider), _user);
    });
  });
}
