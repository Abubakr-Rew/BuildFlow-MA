import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/reports/domain/entities/draft_report.dart';
import 'package:buildflow/features/reports/domain/entities/report.dart';

/// Report repository contract.
abstract class ReportRepository {
  /// Get all reports for the current user's company.
  Future<Result<List<Report>>> getReports();

  /// Get reports filtered by project.
  Future<Result<List<Report>>> getReportsByProject(String projectId);

  /// Get a single report by ID.
  Future<Result<Report>> getReport(String id);

  /// Submit a new report (foreman only).
  Future<Result<Report>> submitReport({
    required String projectId,
    required String text,
    required List<String> photoPaths,
  });

  /// Save a draft report locally.
  Future<Result<DraftReport>> saveDraft(DraftReport draft);

  /// Get all local drafts.
  Future<Result<List<DraftReport>>> getDrafts();

  /// Delete a draft.
  Future<Result<void>> deleteDraft(String draftId);
}
