import 'dart:async';

import 'package:buildflow/core/config.dart';
import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/storage/storage_providers.dart';
import 'package:buildflow/core/supabase/supabase_providers.dart';
import 'package:buildflow/features/auth/data/fake_auth_repository.dart';
import 'package:buildflow/features/auth/data/supabase_auth_repository.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/domain/repositories/auth_repository.dart';
import 'package:buildflow/features/team/domain/entities/invite_code.dart';
import 'package:buildflow/features/team/presentation/providers/fake_team_store_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── DI providers ─────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => switch (kBackend) {
    Backend.fake => FakeAuthRepository(
        secureStorage: ref.watch(secureStorageProvider),
        teamStore: ref.watch(fakeTeamStoreProvider),
      ),
    Backend.supabase => SupabaseAuthRepository(
        gateway: ref.watch(supabaseGatewayProvider),
        localStorage: ref.watch(localStorageProvider),
      ),
  },
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
    final repo = ref.watch(authRepositoryProvider);
    // The session ended without a logout (expired, account removed): back
    // to the login screen, which says why. The router follows the state.
    final ended = repo.sessionEnded.listen((failure) {
      if (state.user == null) return;
      state = AuthState(status: AuthStatus.unauthenticated, failure: failure);
    });
    ref.onDispose(() => unawaited(ended.cancel()));
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
        // A removed account is told so; any other failure just shows the
        // login screen.
        failure: (f) => AuthState(
          status: AuthStatus.unauthenticated,
          failure: f.code == FailureCode.accountDisabled ? f : null,
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

  Future<Result<User>> login({
    required String email,
    required String password,
  }) =>
      _signIn(() => _repo.login(email: email, password: password));

  Future<Result<User>> register({
    required String email,
    required String password,
    required String name,
    required String companyName,
  }) =>
      _signIn(
        () => _repo.register(
          email: email,
          password: password,
          name: name,
          companyName: companyName,
        ),
      );

  /// Joins the company of [inviteCode] with the role it was issued for.
  /// The code is normalized here, so both repositories get `ABC234`
  /// whether the member typed `abc 234` or `ABC-234`.
  Future<Result<User>> joinWithInviteCode({
    required String inviteCode,
    required String name,
    required String email,
    required String password,
  }) =>
      _signIn(
        () => _repo.joinWithInviteCode(
          email: email,
          password: password,
          name: name,
          inviteCode: normalizeInviteCode(inviteCode),
        ),
      );

  /// Signs the user in if [request] succeeds; otherwise keeps the failure
  /// in the state for the form. Never throws.
  Future<Result<User>> _signIn(Future<Result<User>> Function() request) async {
    state = state.copyWith(isLoading: true);
    Result<User> result;
    try {
      result = await request();
    } catch (e, stackTrace) {
      result = Err(
        Failure(FailureCode.unknown, message: '$e', stackTrace: stackTrace),
      );
    }
    state = result.when(
      success: (user) => AuthState(status: AuthStatus.authenticated, user: user),
      failure: (failure) => state.copyWith(isLoading: false, failure: failure),
    );
    return result;
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
