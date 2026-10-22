import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'member.freezed.dart';
part 'member.g.dart';

@freezed
abstract class Member with _$Member {
  const factory Member({
    required String id,
    required String userId,
    required String name,
    required String email,
    required UserRole role,
    required String companyId,
    @Default([]) List<String> assignedProjectIds,
  }) = _Member;

  factory Member.fromJson(Map<String, dynamic> json) =>
      _$MemberFromJson(json);
}
