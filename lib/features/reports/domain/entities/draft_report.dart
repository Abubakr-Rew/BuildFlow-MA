import 'package:freezed_annotation/freezed_annotation.dart';

part 'draft_report.freezed.dart';
part 'draft_report.g.dart';

@freezed
abstract class DraftReport with _$DraftReport {
  const factory DraftReport({
    required String id,
    required String projectId,
    required String projectName,
    required String text,
    required List<String> photoPaths,
    required DateTime createdAt,
  }) = _DraftReport;

  factory DraftReport.fromJson(Map<String, dynamic> json) =>
      _$DraftReportFromJson(json);
}
