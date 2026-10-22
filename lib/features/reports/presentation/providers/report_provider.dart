import 'package:buildflow/features/reports/data/fake_report_repository.dart';
import 'package:buildflow/features/reports/domain/entities/report.dart';
import 'package:buildflow/features/reports/domain/repositories/report_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => FakeReportRepository(),
);

final reportsProvider =
    AsyncNotifierProvider<ReportsNotifier, List<Report>>(
  ReportsNotifier.new,
);

class ReportsNotifier extends AsyncNotifier<List<Report>> {
  @override
  Future<List<Report>> build() async {
    final repo = ref.watch(reportRepositoryProvider);
    final result = await repo.getReports();
    return result.when(
      success: (reports) => reports,
      failure: (f) => throw Exception(f.message),
    );
  }

  Future<bool> submitReport({
    required String projectId,
    required String text,
    required List<String> photoPaths,
  }) async {
    final repo = ref.read(reportRepositoryProvider);
    final result = await repo.submitReport(
      projectId: projectId,
      text: text,
      photoPaths: photoPaths,
    );
    return result.when(
      success: (_) {
        ref.invalidateSelf();
        return true;
      },
      failure: (_) => false,
    );
  }
}
