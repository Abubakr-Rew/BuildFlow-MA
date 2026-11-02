import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/team/domain/entities/invite_code.dart';
import 'package:buildflow/features/team/domain/entities/member.dart';
import 'package:buildflow/features/team/domain/repositories/team_repository.dart';

/// API team repository skeleton. Selected with `Backend.supabase` until replaced;
/// every call fails until the backend is available.
class ApiTeamRepository implements TeamRepository {
  @override
  Future<Result<List<Member>>> getMembers() async {
    // TODO: Implement with Dio
    return const Err(
      Failure(FailureCode.server, message: 'API not implemented'),
    );
  }

  @override
  Future<Result<InviteCode>> generateInviteCode({
    required UserRole role,
  }) async {
    return const Err(
      Failure(FailureCode.server, message: 'API not implemented'),
    );
  }

  @override
  Future<Result<void>> removeMember(String memberId) async {
    return const Err(
      Failure(FailureCode.server, message: 'API not implemented'),
    );
  }
}
