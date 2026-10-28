import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/team/domain/entities/invite_code.dart';
import 'package:buildflow/features/team/domain/entities/member.dart';

/// Team repository contract.
abstract class TeamRepository {
  /// Get all members of the current user's company.
  Future<Result<List<Member>>> getMembers();

  /// Generate a one-time invite code for a new [role] member (foreman or
  /// worker). Whoever joins with it gets this role in the company.
  Future<Result<InviteCode>> generateInviteCode({required UserRole role});

  /// Remove a member from the company (owner only).
  Future<Result<void>> removeMember(String memberId);
}
