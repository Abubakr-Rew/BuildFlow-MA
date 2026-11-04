import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/team/data/fake_team_store.dart';
import 'package:buildflow/features/team/domain/entities/invite_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeInviteCode', () {
    test('trims, upper-cases and drops inner spaces and dashes', () {
      expect(normalizeInviteCode(' k7m-2qx '), 'K7M2QX');
      expect(normalizeInviteCode('K7M 2QX'), 'K7M2QX');
      expect(normalizeInviteCode('k7-m 2-qx\t'), 'K7M2QX');
      expect(normalizeInviteCode('K7M2QX'), 'K7M2QX');
    });
  });

  group('FakeTeamStore invites', () {
    late DateTime now;
    late FakeTeamStore store;

    setUp(() {
      now = DateTime(2026, 10, 28, 12);
      store = FakeTeamStore(now: () => now);
    });

    test('codes avoid look-alike characters', () {
      final codes = [
        for (var i = 0; i < 200; i++)
          store.createInvite(companyId: 'company-1', role: UserRole.worker),
      ].map((i) => i.code);

      for (final code in codes) {
        expect(code, hasLength(inviteCodeLength));
        expect(code, isNot(matches(RegExp('[01OIL]'))));
        expect(code.split('').every(inviteCodeAlphabet.contains), isTrue);
      }
      expect(codes.toSet(), hasLength(codes.length));
    });

    test('a code carries its role and company and expires in 7 days', () {
      final invite =
          store.createInvite(companyId: 'company-1', role: UserRole.foreman);
      expect(invite.role, UserRole.foreman);
      expect(invite.companyId, 'company-1');
      expect(invite.expiresAt, now.add(const Duration(days: 7)).toUtc());
      expect(invite.createdAt.isUtc, isTrue);
      expect(invite.expiresAt!.isUtc, isTrue);
      expect(invite.isUsed, isFalse);
    });

    test('a code can be redeemed once', () {
      final invite =
          store.createInvite(companyId: 'company-1', role: UserRole.worker);
      expect(store.redeemInvite(invite.code)?.role, UserRole.worker);
      expect(store.redeemInvite(invite.code), isNull);
    });

    test('redeems a code typed with spaces, dashes and lower case', () {
      final invite =
          store.createInvite(companyId: 'company-1', role: UserRole.worker);
      final code = invite.code;
      final typed = ' ${code.substring(0, 3).toLowerCase()}-'
          '${code.substring(3)} ';
      expect(store.redeemInvite(typed)?.code, code);
    });

    test('rejects an unknown code', () {
      expect(store.redeemInvite('ZZZZZZ'), isNull);
    });

    test('rejects an expired code', () {
      final invite =
          store.createInvite(companyId: 'company-1', role: UserRole.worker);
      now = now.add(const Duration(days: 7));
      expect(store.redeemInvite(invite.code), isNull);
    });
  });
}
