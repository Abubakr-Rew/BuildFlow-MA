import 'package:buildflow/core/config.dart';
import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/storage/storage_providers.dart';
import 'package:buildflow/features/auth/data/api_auth_repository.dart';
import 'package:buildflow/features/auth/data/fake_auth_repository.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── DI providers ─────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => kUseMockData
      ? FakeAuthRepository(secureStorage: ref.watch(secureStorageProvider))
      : ApiAuthRepository(),
);

// ── Auth state ───────────────────────────────────────────────

enum AuthStatus { initial, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.isLoading = false,
    this.failure,
  });

  final AuthStatus status;
  final User? user;
  final bool isLoading;

  /// Why the last login or registration failed; shown through
  /// `l10n.failureMessage`. Cleared by the next state change.
  final Failure? failure;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isOwner => user?.role == UserRole.owner;
  bool get isForeman => user?.role == UserRole.foreman;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    bool? isLoading,
    Failure? failure,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      failure: failure,
    );
  }
}

// ── Auth notifier ────────────────────────────────────────────

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // A different repository starts a fresh session state.
    ref.watch(authRepositoryProvider);
    return const AuthState();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> restoreSession() async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _repo.restoreSession();
      state = result.when(
        success: (user) => AuthState(
          status: AuthStatus.authenticated,
          user: user,
        ),
        failure: (_) => const AuthState(
          status: AuthStatus.unauthenticated,
        ),
      );
    } catch (_) {
      // Any unexpected error — treat as unauthenticated
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Drops any in-progress session restore and shows the login screen.
  void forceUnauthenticated() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _repo.login(email: email, password: password);
      return result.when<bool>(
        success: (user) {
          state = AuthState(
            status: AuthStatus.authenticated,
            user: user,
          );
          return true;
        },
        failure: (failure) {
          state = state.copyWith(isLoading: false, failure: failure);
          return false;
        },
      );
    } catch (e, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        failure: Failure(
          FailureCode.unknown,
          message: '$e',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String companyName,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _repo.register(
        email: email,
        password: password,
        name: name,
        companyName: companyName,
      );
      return result.when<bool>(
        success: (user) {
          state = AuthState(
            status: AuthStatus.authenticated,
            user: user,
          );
          return true;
        },
        failure: (failure) {
          state = state.copyWith(isLoading: false, failure: failure);
          return false;
        },
      );
    } catch (e, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        failure: Failure(
          FailureCode.unknown,
          message: '$e',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// The logged-in user. Lists depending on it reload when the user changes.
final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(authProvider.select((s) => s.user)),
);
