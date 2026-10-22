// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Member _$MemberFromJson(Map<String, dynamic> json) => _Member(
  id: json['id'] as String,
  userId: json['userId'] as String,
  name: json['name'] as String,
  email: json['email'] as String,
  role: $enumDecode(_$UserRoleEnumMap, json['role']),
  companyId: json['companyId'] as String,
  assignedProjectIds:
      (json['assignedProjectIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$MemberToJson(_Member instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'name': instance.name,
  'email': instance.email,
  'role': _$UserRoleEnumMap[instance.role]!,
  'companyId': instance.companyId,
  'assignedProjectIds': instance.assignedProjectIds,
};

const _$UserRoleEnumMap = {
  UserRole.owner: 'owner',
  UserRole.foreman: 'foreman',
};
