import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/features/team/data/fake_team_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeTeamRepository repo;

  setUp(() {
    repo = FakeTeamRepository();
  });

  group('FakeTeamRepository', () {
    test('getMembers returns seeded members', () async {
      final result = await repo.getMembers();
      expect(result.value.length, 5);
    });

    test('generateInviteCode returns a 6-character code', () async {
      final result = await repo.generateInviteCode();
      expect(result.value.code, hasLength(6));
    });

    test('removeMember removes an existing member', () async {
      expect((await repo.removeMember('member-2')).isSuccess, isTrue);
      expect((await repo.getMembers()).value.length, 4);
    });

    test('removeMember fails with notFound for an unknown member', () async {
      final result = await repo.removeMember('nonexistent');
      expect(result.failure.code, FailureCode.notFound);
    });
  });
}
