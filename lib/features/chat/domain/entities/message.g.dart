// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Message _$MessageFromJson(Map<String, dynamic> json) => _Message(
  id: json['id'] as String,
  clientId: json['clientId'] as String,
  chatId: json['chatId'] as String,
  senderId: json['senderId'] as String,
  kind: $enumDecode(_$MessageKindEnumMap, json['kind']),
  createdAt: DateTime.parse(json['createdAt'] as String),
  status:
      $enumDecodeNullable(_$MessageStatusEnumMap, json['status']) ??
      MessageStatus.sent,
  text: json['text'] as String?,
  attachments:
      (json['attachments'] as List<dynamic>?)
          ?.map((e) => MessageAttachment.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  reportId: json['reportId'] as String?,
  systemEvent: $enumDecodeNullable(
    _$ChatSystemEventEnumMap,
    json['systemEvent'],
  ),
  subjectUserId: json['subjectUserId'] as String?,
);

Map<String, dynamic> _$MessageToJson(_Message instance) => <String, dynamic>{
  'id': instance.id,
  'clientId': instance.clientId,
  'chatId': instance.chatId,
  'senderId': instance.senderId,
  'kind': _$MessageKindEnumMap[instance.kind]!,
  'createdAt': instance.createdAt.toIso8601String(),
  'status': _$MessageStatusEnumMap[instance.status]!,
  'text': instance.text,
  'attachments': instance.attachments.map((e) => e.toJson()).toList(),
  'reportId': instance.reportId,
  'systemEvent': _$ChatSystemEventEnumMap[instance.systemEvent],
  'subjectUserId': instance.subjectUserId,
};

const _$MessageKindEnumMap = {
  MessageKind.text: 'text',
  MessageKind.photo: 'photo',
  MessageKind.voice: 'voice',
  MessageKind.report: 'report',
  MessageKind.system: 'system',
};

const _$MessageStatusEnumMap = {
  MessageStatus.sending: 'sending',
  MessageStatus.sent: 'sent',
  MessageStatus.read: 'read',
  MessageStatus.failed: 'failed',
};

const _$ChatSystemEventEnumMap = {
  ChatSystemEvent.memberAdded: 'memberAdded',
  ChatSystemEvent.memberRemoved: 'memberRemoved',
};
