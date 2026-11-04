import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/supabase/json.dart';
import 'package:buildflow/core/supabase/supabase_gateway.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/team/domain/entities/invite_code.dart';
import 'package:buildflow/features/team/domain/entities/member.dart';
import 'package:buildflow/features/team/domain/repositories/team_repository.dart';

/// [TeamRepository] over `get_members`, `create_invite` and the Edge
/// Function `remove-member`, which also takes the member off every
/// project and chat and blocks their sign-in.
class SupabaseTeamRepository implements TeamRepository {
  SupabaseTeamRepository({required this.gateway});

  final SupabaseGateway gateway;

  @override
  Future<Result<List<Member>>> getMembers() =>
      gateway.rpc('get_members', listOf(Member.fromJson));

  @override
  Future<Result<InviteCode>> generateInviteCode({required UserRole role}) =>
      gateway.rpc(
        'create_invite',
        one(InviteCode.fromJson),
        params: {'p_role': role.name},
      );

  @override
  Future<Result<void>> removeMember(String memberId) => gateway.invoke(
        'remove-member',
        (_) {},
        body: {'memberId': memberId},
      );
}
