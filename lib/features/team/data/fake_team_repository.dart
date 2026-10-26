import 'dart:math';

import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/team/domain/entities/invite_code.dart';
import 'package:buildflow/features/team/domain/entities/member.dart';
import 'package:buildflow/features/team/domain/repositories/team_repository.dart';

/// In-memory fake team repository with seeded demo data.
class FakeTeamRepository implements TeamRepository {
  FakeTeamRepository({this.companyId = 'company-1'});

  final String companyId;
  final _random = Random();

  final List<Member> _members = [
    const Member(
      id: 'member-1',
      userId: 'user-owner-1',
      name: 'Асан Бекович',
      email: 'owner@buildflow.kg',
      role: UserRole.owner,
      companyId: 'company-1',
    ),
    const Member(
      id: 'member-2',
      userId: 'user-foreman-1',
      name: 'Бакыт Касымов',
      email: 'foreman1@buildflow.kg',
      role: UserRole.foreman,
      companyId: 'company-1',
      assignedProjectIds: ['project-1', 'project-2'],
    ),
    const Member(
      id: 'member-3',
      userId: 'user-foreman-2',
      name: 'Данияр Жумабеков',
      email: 'foreman2@buildflow.kg',
      role: UserRole.foreman,
      companyId: 'company-1',
      assignedProjectIds: ['project-2', 'project-3'],
    ),
    const Member(
      id: 'member-4',
      userId: 'user-worker-1',
      name: 'Эрлан Токтосунов',
      email: 'worker1@buildflow.kg',
      role: UserRole.worker,
      companyId: 'company-1',
      assignedProjectIds: ['project-1', 'project-2'],
    ),
    const Member(
      id: 'member-5',
      userId: 'user-worker-2',
      name: 'Нурлан Абдыраев',
      email: 'worker2@buildflow.kg',
      role: UserRole.worker,
      companyId: 'company-1',
      assignedProjectIds: ['project-2', 'project-3'],
    ),
  ];

  Future<void> _simulateLatency() async {
    final ms = 200 + _random.nextInt(400);
    await Future<void>.delayed(Duration(milliseconds: ms));
  }

  @override
  Future<Result<List<Member>>> getMembers() async {
    await _simulateLatency();
    final filtered = _members
        .where((m) => m.companyId == companyId)
        .toList();
    return Success(filtered);
  }

  @override
  Future<Result<InviteCode>> generateInviteCode() async {
    await _simulateLatency();
    final code = List.generate(
      6,
      (_) => 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'[_random.nextInt(36)],
    ).join();
    final invite = InviteCode(
      code: code,
      companyId: companyId,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );
    return Success(invite);
  }

  @override
  Future<Result<void>> removeMember(String memberId) async {
    await _simulateLatency();
    final index = _members.indexWhere((m) => m.id == memberId);
    if (index == -1) {
      return Err(
        Failure(FailureCode.notFound, message: 'Member $memberId not found'),
      );
    }
    _members.removeAt(index);
    return const Success(null);
  }
}
