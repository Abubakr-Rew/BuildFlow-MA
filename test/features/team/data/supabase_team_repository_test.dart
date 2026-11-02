import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/team/data/supabase_team_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_supabase.dart';

void main() {
  late FakeSupabase supabase;
  late SupabaseTeamRepository repo;

  setUp(() async {
    supabase = FakeSupabase();
    await supabase.signIn('owner');
    repo = SupabaseTeamRepository(gateway: supabase.gateway);
  });
  tearDown(() => supabase.dispose());

  test('get_members is the team', () async {
    supabase.rpc('get_members', [
      {
        'id': 'u2',
        'userId': 'u2',
        'name': 'Бакыт Касымов',
        'email': 'foreman1@buildflow.kg',
        'role': 'foreman',
        'companyId': 'c1',
        'assignedProjectIds': ['p1'],
      },
    ]);

    final members = (await repo.getMembers()).value;

    expect(members.single.role, UserRole.foreman);
    expect(members.single.assignedProjectIds, ['p1']);
  });

  test('create_invite takes the role and returns the code', () async {
    supabase.rpc('create_invite', {
      'code': 'K7M2QX',
      'companyId': 'c1',
      'role': 'worker',
      'createdAt': '2026-11-02T10:00:00Z',
      'expiresAt': '2026-11-09T10:00:00Z',
      'isUsed': false,
    });

    final invite =
        (await repo.generateInviteCode(role: UserRole.worker)).value;

    expect(invite.code, 'K7M2QX');
    expect(invite.expiresAt, DateTime.utc(2026, 11, 9, 10));
    expect(supabase.rpcCalls('create_invite').single, {'p_role': 'worker'});
  });

  test('removing a member goes through the Edge Function', () async {
    supabase.function('remove-member', const FakeReply(204));

    final result = await repo.removeMember('u5');

    expect(result.isSuccess, isTrue);
    expect(
      supabase.requestsTo('/functions/v1/remove-member').single.json,
      {'memberId': 'u5'},
    );
  });

  test('removing someone already removed is notFound', () async {
    supabase.function(
      'remove-member',
      const FakeReply(404, {'error': 'x', 'hint': 'not_found'}),
    );

    expect(
      (await repo.removeMember('u5')).failure.code,
      FailureCode.notFound,
    );
  });

  test('only the director may remove', () async {
    supabase.function(
      'remove-member',
      const FakeReply(403, {'error': 'x', 'hint': 'owner_only'}),
    );

    expect(
      (await repo.removeMember('u5')).failure.code,
      FailureCode.forbidden,
    );
  });
}
