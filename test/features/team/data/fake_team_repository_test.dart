import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/team/data/fake_team_repository.dart';
import 'package:buildflow/features/team/data/fake_team_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeTeamRepository repo;

  setUp(() {
    repo = FakeTeamRepository(store: FakeTeamStore());
  });

  group('FakeTeamRepository', () {
    test('getMembers returns seeded members', () async {
      final result = await repo.getMembers();
      expect(result.value.length, 6);
    });

    test('generateInviteCode returns a 6-character code for the role',
        () async {
      final result = await repo.generateInviteCode(role: UserRole.worker);
      expect(result.value.code, hasLength(6));
      expect(result.value.role, UserRole.worker);
      expect(result.value.companyId, 'company-1');
    });

    test('generateInviteCode refuses to invite a director', () async {
      final result = await repo.generateInviteCode(role: UserRole.owner);
      expect(result.failure.code, FailureCode.validation);
    });

    test('removeMember removes an existing member', () async {
      expect((await repo.removeMember('member-2')).isSuccess, isTrue);
      expect((await repo.getMembers()).value.length, 5);
    });

    test('removeMember fails with notFound for an unknown member', () async {
      final result = await repo.removeMember('nonexistent');
      expect(result.failure.code, FailureCode.notFound);
    });
  });
}
