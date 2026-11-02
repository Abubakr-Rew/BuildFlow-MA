import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';

/// Auth repository contract. Implemented by FakeAuthRepository and
/// SupabaseAuthRepository.
abstract class AuthRepository {
  /// Authenticate with email and password.
  Future<Result<User>> login({
    required String email,
    required String password,
  });

  /// Register a new owner account and create a company.
  Future<Result<User>> register({
    required String email,
    required String password,
    required String name,
    required String companyName,
  });

  /// Register a member with an invite code. The role and company come from
  /// the code; an unknown, used or expired code is `invalidInviteCode`,
  /// a registered email is `emailTaken` (the code stays valid then).
  Future<Result<User>> joinWithInviteCode({
    required String email,
    required String password,
    required String name,
    required String inviteCode,
  });

  /// Restore session from stored token.
  Future<Result<User>> restoreSession();

  /// Clear the current session.
  Future<Result<void>> logout();

  /// Fires when the session ends without [logout]: it can no longer be
  /// refreshed, or the server says the account is gone. Carries why
  /// (`sessionExpired`, `accountDisabled`).
  Stream<Failure> get sessionEnded;

  /// Get the current authenticated user, or null.
  User? get currentUser;
}
