import 'package:buildflow/core/config.dart';
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
    this.errorMessage,
  });

  final AuthStatus status;
  final User? user;
  final bool isLoading;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isOwner => user?.role == UserRole.owner;
  bool get isForeman => user?.role == UserRole.foreman;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

// ── Auth notifier ────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthState());

  final AuthRepository _repo;

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
          state = state.copyWith(
            isLoading: false,
            errorMessage: failure.message,
          );
          return false;
        },
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Что-то пошло не так',
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
          state = state.copyWith(
            isLoading: false,
            errorMessage: failure.message,
          );
          return false;
        },
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Что-то пошло не так',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(authRepositoryProvider)),
);

/// The logged-in user. Lists depending on it reload when the user changes.
final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(authProvider.select((s) => s.user)),
);
