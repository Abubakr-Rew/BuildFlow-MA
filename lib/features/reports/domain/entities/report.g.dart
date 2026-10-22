// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Report _$ReportFromJson(Map<String, dynamic> json) => _Report(
  id: json['id'] as String,
  projectId: json['projectId'] as String,
  projectName: json['projectName'] as String,
  authorId: json['authorId'] as String,
  authorName: json['authorName'] as String,
  text: json['text'] as String,
  photos: (json['photos'] as List<dynamic>)
      .map((e) => ReportPhoto.fromJson(e as Map<String, dynamic>))
      .toList(),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$ReportToJson(_Report instance) => <String, dynamic>{
  'id': instance.id,
  'projectId': instance.projectId,
  'projectName': instance.projectName,
  'authorId': instance.authorId,
  'authorName': instance.authorName,
  'text': instance.text,
  'photos': instance.photos,
  'createdAt': instance.createdAt.toIso8601String(),
};
