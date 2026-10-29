// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_photo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReportPhoto _$ReportPhotoFromJson(Map<String, dynamic> json) => _ReportPhoto(
  id: json['id'] as String,
  url: json['url'] as String,
  thumbnailUrl: json['thumbnailUrl'] as String?,
  takenAt: json['takenAt'] == null
      ? null
      : DateTime.parse(json['takenAt'] as String),
);

Map<String, dynamic> _$ReportPhotoToJson(_ReportPhoto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'thumbnailUrl': instance.thumbnailUrl,
      'takenAt': instance.takenAt?.toIso8601String(),
    };
