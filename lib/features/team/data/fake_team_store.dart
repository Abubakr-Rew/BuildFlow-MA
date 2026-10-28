import 'dart:math';

import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/team/domain/entities/invite_code.dart';
import 'package:buildflow/features/team/domain/entities/member.dart';

/// The company's members and invite codes in demo mode: an in-memory stand-in
/// for the server, shared by FakeTeamRepository and FakeAuthRepository, so a
/// code the director creates on the team screen works on the join screen.
///
/// Created only by `fakeTeamStoreProvider`; tests may create their own.
class FakeTeamStore {
  FakeTeamStore({DateTime Function()? now, Random? random})
      : _now = now ?? DateTime.now,
        _random = random ?? Random();

  final DateTime Function() _now;
  final Random _random;

  static const inviteLifetime = Duration(days: 7);

  final Map<String, InviteCode> _invites = {};

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
    const Member(
      id: 'member-6',
      userId: 'user-worker-3',
      name: 'Азамат Асанов',
      email: 'worker3@buildflow.kg',
      role: UserRole.worker,
      companyId: 'company-1',
      assignedProjectIds: ['project-3'],
    ),
  ];

  // ── Members ────────────────────────────────────────────────

  List<Member> membersOf(String companyId) =>
      _members.where((m) => m.companyId == companyId).toList();

  /// The member with [userId], or `null` if they aren't (any longer) in a
  /// company.
  Member? memberByUserId(String userId) =>
      _members.where((m) => m.userId == userId).firstOrNull;

  void addMember(Member member) {
    _members.add(member);
    _notifyMembers();
  }

  /// Whether a member was removed.
  bool removeMember(String memberId) {
    final before = _members.length;
    _members.removeWhere((m) => m.id == memberId);
    final removed = _members.length < before;
    if (removed) _notifyMembers();
    return removed;
  }

  final List<void Function()> _listeners = [];

  /// Called after a member joins or is removed. FakeChatStore listens to
  /// take the chats away from removed members, as the server does.
  void addMembersListener(void Function() listener) =>
      _listeners.add(listener);

  void removeMembersListener(void Function() listener) =>
      _listeners.remove(listener);

  void _notifyMembers() {
    for (final listener in [..._listeners]) {
      listener();
    }
  }

  // ── Invite codes ───────────────────────────────────────────

  InviteCode createInvite({required String companyId, required UserRole role}) {
    String code;
    do {
      code = List.generate(
        inviteCodeLength,
        (_) => inviteCodeAlphabet[_random.nextInt(inviteCodeAlphabet.length)],
      ).join();
    } while (_invites.containsKey(code));

    final now = _now();
    final invite = InviteCode(
      code: code,
      companyId: companyId,
      role: role,
      createdAt: now,
      expiresAt: now.add(inviteLifetime),
    );
    _invites[code] = invite;
    return invite;
  }

  /// Marks the code as used and returns it, or `null` if it is unknown,
  /// already used or expired.
  InviteCode? redeemInvite(String code) {
    final key = normalizeInviteCode(code);
    final invite = _invites[key];
    if (invite == null || invite.isUsed) return null;
    final expiresAt = invite.expiresAt;
    if (expiresAt != null && !_now().isBefore(expiresAt)) return null;

    final used = invite.copyWith(isUsed: true);
    _invites[key] = used;
    return used;
  }
}
