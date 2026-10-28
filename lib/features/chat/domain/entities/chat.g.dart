// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Chat _$ChatFromJson(Map<String, dynamic> json) => _Chat(
  id: json['id'] as String,
  type: $enumDecode(_$ChatTypeEnumMap, json['type']),
  participantIds: (json['participantIds'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  projectId: json['projectId'] as String?,
  title: json['title'] as String? ?? '',
  lastMessage: json['lastMessage'] == null
      ? null
      : Message.fromJson(json['lastMessage'] as Map<String, dynamic>),
  unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$ChatToJson(_Chat instance) => <String, dynamic>{
  'id': instance.id,
  'type': _$ChatTypeEnumMap[instance.type]!,
  'participantIds': instance.participantIds,
  'updatedAt': instance.updatedAt.toIso8601String(),
  'projectId': instance.projectId,
  'title': instance.title,
  'lastMessage': instance.lastMessage?.toJson(),
  'unreadCount': instance.unreadCount,
};

const _$ChatTypeEnumMap = {
  ChatType.direct: 'direct',
  ChatType.project: 'project',
};
