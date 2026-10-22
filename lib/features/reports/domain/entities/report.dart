import 'package:buildflow/features/reports/domain/entities/report_photo.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'report.freezed.dart';
part 'report.g.dart';

@freezed
abstract class Report with _$Report {
  const factory Report({
    required String id,
    required String projectId,
    required String projectName,
    required String authorId,
    required String authorName,
    required String text,
    required List<ReportPhoto> photos,
    required DateTime createdAt,
  }) = _Report;

  factory Report.fromJson(Map<String, dynamic> json) =>
      _$ReportFromJson(json);
}
