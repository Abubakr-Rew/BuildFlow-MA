import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';

/// Auth repository contract. Implemented by FakeAuthRepository and
/// ApiAuthRepository.
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

  /// Register a foreman using an invite code.
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

  /// Get the current authenticated user, or null.
  User? get currentUser;
}
