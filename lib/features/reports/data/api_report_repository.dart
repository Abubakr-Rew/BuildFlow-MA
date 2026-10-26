import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/reports/domain/entities/draft_report.dart';
import 'package:buildflow/features/reports/domain/entities/report.dart';
import 'package:buildflow/features/reports/domain/repositories/report_repository.dart';

/// API report repository skeleton. Selected when `kUseMockData` is false;
/// every call fails until the backend is available.
class ApiReportRepository implements ReportRepository {
  @override
  Future<Result<List<Report>>> getReports() async {
    // TODO: Implement with Dio
    return const Err(
      ServerFailure(message: 'API not implemented'),
    );
  }

  @override
  Future<Result<List<Report>>> getReportsByProject(String projectId) async {
    return const Err(
      ServerFailure(message: 'API not implemented'),
    );
  }

  @override
  Future<Result<Report>> getReport(String id) async {
    return const Err(
      ServerFailure(message: 'API not implemented'),
    );
  }

  @override
  Future<Result<Report>> submitReport({
    required String projectId,
    required String projectName,
    required String authorId,
    required String authorName,
    required String text,
    required List<String> photoPaths,
  }) async {
    return const Err(
      ServerFailure(message: 'API not implemented'),
    );
  }

  @override
  Future<Result<DraftReport>> saveDraft(DraftReport draft) async {
    return const Err(
      ServerFailure(message: 'API not implemented'),
    );
  }

  @override
  Future<Result<List<DraftReport>>> getDrafts() async {
    return const Err(
      ServerFailure(message: 'API not implemented'),
    );
  }

  @override
  Future<Result<void>> deleteDraft(String draftId) async {
    return const Err(
      ServerFailure(message: 'API not implemented'),
    );
  }
}
