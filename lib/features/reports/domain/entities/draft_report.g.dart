// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'draft_report.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DraftReport _$DraftReportFromJson(Map<String, dynamic> json) => _DraftReport(
  id: json['id'] as String,
  projectId: json['projectId'] as String,
  projectName: json['projectName'] as String,
  text: json['text'] as String,
  photoPaths: (json['photoPaths'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$DraftReportToJson(_DraftReport instance) =>
    <String, dynamic>{
      'id': instance.id,
      'projectId': instance.projectId,
      'projectName': instance.projectName,
      'text': instance.text,
      'photoPaths': instance.photoPaths,
      'createdAt': instance.createdAt.toIso8601String(),
    };
