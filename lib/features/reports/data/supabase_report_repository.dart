import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/photos/compressed_photo.dart';
import 'package:buildflow/core/supabase/json.dart';
import 'package:buildflow/core/supabase/supabase_gateway.dart';
import 'package:buildflow/core/supabase/supabase_uploads.dart';
import 'package:buildflow/features/reports/domain/entities/draft_report.dart';
import 'package:buildflow/features/reports/domain/entities/report.dart';
import 'package:buildflow/features/reports/domain/repositories/report_repository.dart';

/// [ReportRepository] over the report RPCs. Photos are uploaded first
/// ([SupabaseUploads]), then the report refers to them by attachment id;
/// a retried report doesn't upload its photos again. Their `url` is
/// `storage:<bucket>/<path>`, signed when shown. Drafts stay on the phone.
class SupabaseReportRepository implements ReportRepository {
  SupabaseReportRepository({required this.gateway, required this.uploads});

  final SupabaseGateway gateway;
  final SupabaseUploads uploads;

  final List<DraftReport> _drafts = [];

  @override
  Future<Result<List<Report>>> getReports() =>
      gateway.rpc('get_reports', listOf(Report.fromJson));

  @override
  Future<Result<List<Report>>> getReportsByProject(String projectId) =>
      gateway.rpc(
        'get_reports',
        listOf(Report.fromJson),
        params: {'p_project_id': projectId},
      );

  @override
  Future<Result<Report>> getReport(String id) =>
      gateway.rpc('get_report', one(Report.fromJson), params: {'p_id': id});

  /// The author and the project name come from the session and the
  /// database; [projectName], [authorId] and [authorName] aren't sent.
  @override
  Future<Result<Report>> submitReport({
    required String projectId,
    required String projectName,
    required String authorId,
    required String authorName,
    required String text,
    required List<CompressedPhoto> photos,
  }) async {
    final attached = <Map<String, dynamic>>[];
    for (final photo in photos) {
      final uploaded = await uploads.photo(photo);
      if (uploaded case Err(:final failure)) return Err(failure);
      attached.add({
        'attachmentId': uploaded.value.attachmentId,
        'takenAt': photo.takenAt?.toUtc().toIso8601String(),
      });
    }
    return gateway.rpc(
      'submit_report',
      one(Report.fromJson),
      params: {
        'p_project_id': projectId,
        'p_text': text.trim(),
        'p_photos': attached,
      },
    );
  }

  @override
  Future<Result<DraftReport>> saveDraft(DraftReport draft) async {
    final index = _drafts.indexWhere((d) => d.id == draft.id);
    if (index >= 0) {
      _drafts[index] = draft;
    } else {
      _drafts.add(draft);
    }
    return Success(draft);
  }

  @override
  Future<Result<List<DraftReport>>> getDrafts() async =>
      Success(List.unmodifiable(_drafts));

  @override
  Future<Result<void>> deleteDraft(String draftId) async {
    _drafts.removeWhere((d) => d.id == draftId);
    return const Success(null);
  }
}
