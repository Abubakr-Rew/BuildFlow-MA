// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite_code.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_InviteCode _$InviteCodeFromJson(Map<String, dynamic> json) => _InviteCode(
  code: json['code'] as String,
  companyId: json['companyId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
  isUsed: json['isUsed'] as bool? ?? false,
);

Map<String, dynamic> _$InviteCodeToJson(_InviteCode instance) =>
    <String, dynamic>{
      'code': instance.code,
      'companyId': instance.companyId,
      'createdAt': instance.createdAt.toIso8601String(),
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'isUsed': instance.isUsed,
    };
