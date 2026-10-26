import 'package:buildflow/features/projects/presentation/providers/project_provider.dart';
import 'package:buildflow/features/reports/data/fake_report_repository.dart';
import 'package:buildflow/features/reports/domain/entities/report.dart';
import 'package:buildflow/features/reports/domain/repositories/report_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => FakeReportRepository(),
);

/// Reports visible to the current user: everything for a director,
/// otherwise only reports for the user's own projects.
final reportsProvider =
    AsyncNotifierProvider<ReportsNotifier, List<Report>>(
  ReportsNotifier.new,
);

class ReportsNotifier extends AsyncNotifier<List<Report>> {
  @override
  Future<List<Report>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];

    final visibleProjectIds =
        (await ref.watch(projectsProvider.future)).map((p) => p.id).toSet();

    final repo = ref.watch(reportRepositoryProvider);
    final result = await repo.getReports();
    return result.when(
      success: (reports) => reports
          .where((r) => visibleProjectIds.contains(r.projectId))
          .toList(),
      failure: (f) => throw Exception(f.message),
    );
  }

  Future<bool> submitReport({
    required String projectId,
    required String text,
    required List<String> photoPaths,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return false;

    final projects = await ref.read(projectsProvider.future);
    final project = projects.where((p) => p.id == projectId).firstOrNull;
    if (project == null) return false;

    final repo = ref.read(reportRepositoryProvider);
    final result = await repo.submitReport(
      projectId: projectId,
      projectName: project.name,
      authorId: user.id,
      authorName: user.name,
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
