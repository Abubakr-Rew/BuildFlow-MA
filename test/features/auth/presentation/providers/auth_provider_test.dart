import 'dart:async';
import 'dart:io';

import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/remote_files/remote_files.dart';
import 'package:buildflow/core/remote_files/remote_files_providers.dart';
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
  final ended = StreamController<Failure>.broadcast();

  @override
  Stream<Failure> get sessionEnded => ended.stream;

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
  late Directory cache;

  AuthState state() => container.read(authProvider);
  AuthNotifier notifier() => container.read(authProvider.notifier);

  setUp(() async {
    repo = _StubAuthRepository();
    cache = await Directory.systemTemp.createTemp('auth_provider_test');
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        remoteFilesProvider.overrideWithValue(
          RemoteFiles(cacheDir: () async => cache.path),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await cache.delete(recursive: true);
    });
  });

  /// Waits for the unawaited clear (real file I/O) to delete [file].
  Future<bool> deleted(File file) async {
    for (var i = 0; i < 50 && file.existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return !file.existsSync();
  }

  /// A downloaded photo of the user signed in now.
  File downloaded() =>
      File('${cache.path}/remote/a1.jpg')
        ..createSync(recursive: true)
        ..writeAsStringSync('photo');

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
      expect((await done).value, _user);
      expect(state().status, AuthStatus.authenticated);
      expect(state().user, _user);
      expect(state().isLoading, isFalse);
      expect(state().failure, isNull);
    });

    test('failed login keeps the user signed out with the failure', () async {
      notifier().forceUnauthenticated();
      repo.result = const Err(Failure(FailureCode.invalidCredentials));

      final result = await notifier().login(email: 'a@b.kg', password: 'x');
      expect(result.failure.code, FailureCode.invalidCredentials);
      expect(state().status, AuthStatus.unauthenticated);
      expect(state().isLoading, isFalse);
      expect(state().failure?.code, FailureCode.invalidCredentials);
    });

    test('an exception from the repository becomes an unknown failure', () async {
      repo.error = Exception('boom');
      final result = await notifier().login(email: 'a@b.kg', password: 'x');
      expect(result.failure.code, FailureCode.unknown);
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
      final result = await notifier().register(
        email: 'a@b.kg',
        password: '123456',
        name: 'Owner',
        companyName: 'Co',
      );
      expect(result.value, _user);
      expect(state().status, AuthStatus.authenticated);
    });

    test('logout signs out', () async {
      await notifier().login(email: 'a@b.kg', password: '123456');
      await notifier().logout();
      expect(state().status, AuthStatus.unauthenticated);
      expect(state().user, isNull);
    });

    test('a session that ends on its own signs out with the reason', () async {
      await notifier().login(email: 'a@b.kg', password: '123456');

      repo.ended.add(const Failure(FailureCode.sessionExpired));
      await pumpEventQueue();

      expect(state().status, AuthStatus.unauthenticated);
      expect(state().user, isNull);
      expect(state().failure?.code, FailureCode.sessionExpired);
    });

    test('a session end while signed out changes nothing', () async {
      notifier().forceUnauthenticated();
      repo.ended.add(const Failure(FailureCode.sessionExpired));
      await pumpEventQueue();
      expect(state().failure, isNull);
    });

    test('restoring a removed account says access is closed', () async {
      repo.result = const Err(Failure(FailureCode.accountDisabled));
      await notifier().restoreSession();
      expect(state().status, AuthStatus.unauthenticated);
      expect(state().failure?.code, FailureCode.accountDisabled);
    });

    group('downloaded files go with the user', () {
      test('on logout', () async {
        await notifier().login(email: 'a@b.kg', password: '123456');
        final file = downloaded();

        await notifier().logout();

        expect(await deleted(file), isTrue);
      });

      test('when the session ends on its own', () async {
        await notifier().login(email: 'a@b.kg', password: '123456');
        final file = downloaded();

        repo.ended.add(const Failure(FailureCode.accountDisabled));

        expect(await deleted(file), isTrue);
      });

      test('when someone signs in', () async {
        final file = downloaded();

        await notifier().login(email: 'a@b.kg', password: '123456');

        expect(await deleted(file), isTrue);
      });

      test('but not on a failed sign-in or a restore', () async {
        final file = downloaded();
        repo.result = const Err(Failure(FailureCode.invalidCredentials));
        await notifier().login(email: 'a@b.kg', password: 'x');
        repo.result = const Success(_user);
        await notifier().restoreSession();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(file.existsSync(), isTrue);
      });
    });

    test('currentUserProvider follows the signed-in user', () async {
      expect(container.read(currentUserProvider), isNull);
      await notifier().login(email: 'a@b.kg', password: '123456');
      expect(container.read(currentUserProvider), _user);
    });
  });
}
