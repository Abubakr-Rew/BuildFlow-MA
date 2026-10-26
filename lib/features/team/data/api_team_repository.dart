import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/team/domain/entities/invite_code.dart';
import 'package:buildflow/features/team/domain/entities/member.dart';
import 'package:buildflow/features/team/domain/repositories/team_repository.dart';

/// API team repository skeleton. Selected when `kUseMockData` is false;
/// every call fails until the backend is available.
class ApiTeamRepository implements TeamRepository {
  @override
  Future<Result<List<Member>>> getMembers() async {
    // TODO: Implement with Dio
    return const Err(
      ServerFailure(message: 'API not implemented'),
    );
  }

  @override
  Future<Result<InviteCode>> generateInviteCode() async {
    return const Err(
      ServerFailure(message: 'API not implemented'),
    );
  }

  @override
  Future<Result<void>> removeMember(String memberId) async {
    return const Err(
      ServerFailure(message: 'API not implemented'),
    );
  }
}
