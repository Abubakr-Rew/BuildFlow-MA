import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'invite_code.freezed.dart';
part 'invite_code.g.dart';

/// A one-time code the director gives to a new member. The member joins
/// [companyId] with [role]; neither is chosen on the join screen.
@freezed
abstract class InviteCode with _$InviteCode {
  const factory InviteCode({
    required String code,
    required String companyId,
    required UserRole role,
    required DateTime createdAt,
    DateTime? expiresAt,
    @Default(false) bool isUsed,
  }) = _InviteCode;

  factory InviteCode.fromJson(Map<String, dynamic> json) =>
      _$InviteCodeFromJson(json);
}

/// Characters of generated codes: no look-alikes (0/O, 1/I/L), since codes
/// are dictated over the phone and retyped from messages.
const inviteCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

const inviteCodeLength = 6;

/// How a typed code is compared: trimmed, upper case, without the spaces and
/// dashes people add when they dictate or forward it (`abc-234` → `ABC234`).
String normalizeInviteCode(String input) =>
    input.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
