import 'dart:math';

import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/team/data/fake_team_store.dart';
import 'package:buildflow/features/team/domain/entities/invite_code.dart';
import 'package:buildflow/features/team/domain/entities/member.dart';
import 'package:buildflow/features/team/domain/repositories/team_repository.dart';

/// Fake team repository over the shared [FakeTeamStore], with seeded demo
/// data and simulated latency.
class FakeTeamRepository implements TeamRepository {
  FakeTeamRepository({required this.store, this.companyId = 'company-1'});

  final FakeTeamStore store;
  final String companyId;
  final _random = Random();

  Future<void> _simulateLatency() async {
    final ms = 200 + _random.nextInt(400);
    await Future<void>.delayed(Duration(milliseconds: ms));
  }

  @override
  Future<Result<List<Member>>> getMembers() async {
    await _simulateLatency();
    return Success(store.membersOf(companyId));
  }

  @override
  Future<Result<InviteCode>> generateInviteCode({
    required UserRole role,
  }) async {
    await _simulateLatency();
    if (role.isOwner) {
      return const Err(
        Failure(FailureCode.validation, message: 'Owners cannot be invited'),
      );
    }
    return Success(store.createInvite(companyId: companyId, role: role));
  }

  @override
  Future<Result<void>> removeMember(String memberId) async {
    await _simulateLatency();
    if (!store.removeMember(memberId)) {
      return Err(
        Failure(FailureCode.notFound, message: 'Member $memberId not found'),
      );
    }
    return const Success(null);
  }
}
