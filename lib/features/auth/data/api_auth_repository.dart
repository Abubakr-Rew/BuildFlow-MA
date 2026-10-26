import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/repositories/auth_repository.dart';

/// API auth repository skeleton. Selected when `kUseMockData` is false;
/// every call fails until the backend is available.
class ApiAuthRepository implements AuthRepository {
  @override
  User? get currentUser => null;

  @override
  Future<Result<User>> login({
    required String email,
    required String password,
  }) async {
    // TODO: Implement with Dio
    return const Err(
      ServerFailure(message: 'API not implemented'),
    );
  }

  @override
  Future<Result<User>> register({
    required String email,
    required String password,
    required String name,
    required String companyName,
  }) async {
    return const Err(
      ServerFailure(message: 'API not implemented'),
    );
  }

  @override
  Future<Result<User>> joinWithInviteCode({
    required String email,
    required String password,
    required String name,
    required String inviteCode,
  }) async {
    return const Err(
      ServerFailure(message: 'API not implemented'),
    );
  }

  @override
  Future<Result<User>> restoreSession() async {
    return const Err(
      ServerFailure(message: 'API not implemented'),
    );
  }

  @override
  Future<Result<void>> logout() async {
    return const Err(
      ServerFailure(message: 'API not implemented'),
    );
  }
}
