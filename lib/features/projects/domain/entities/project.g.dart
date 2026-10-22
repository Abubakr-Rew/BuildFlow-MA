// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Project _$ProjectFromJson(Map<String, dynamic> json) => _Project(
  id: json['id'] as String,
  name: json['name'] as String,
  address: json['address'] as String,
  status: $enumDecode(_$ProjectStatusEnumMap, json['status']),
  companyId: json['companyId'] as String,
  foremanIds:
      (json['foremanIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$ProjectToJson(_Project instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'address': instance.address,
  'status': _$ProjectStatusEnumMap[instance.status]!,
  'companyId': instance.companyId,
  'foremanIds': instance.foremanIds,
};

const _$ProjectStatusEnumMap = {
  ProjectStatus.active: 'active',
  ProjectStatus.paused: 'paused',
  ProjectStatus.finished: 'finished',
};
