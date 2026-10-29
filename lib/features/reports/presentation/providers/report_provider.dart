import 'package:buildflow/core/config.dart';
import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/photos/compressed_photo.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/presentation/providers/project_provider.dart';
import 'package:buildflow/features/reports/data/api_report_repository.dart';
import 'package:buildflow/features/reports/data/fake_report_repository.dart';
import 'package:buildflow/features/reports/domain/entities/report.dart';
import 'package:buildflow/features/reports/domain/repositories/report_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => kUseMockData ? FakeReportRepository() : ApiReportRepository(),
);

/// Reports visible to the current user: everything for a director,
/// otherwise only reports for the user's own projects.
final reportsProvider = AsyncNotifierProvider<ReportsNotifier, List<Report>>(
  ReportsNotifier.new,
);

/// Reports of a single project, newest first.
final projectReportsProvider =
    Provider.family<AsyncValue<List<Report>>, String>(
      (ref, projectId) => ref
          .watch(reportsProvider)
          .whenData(
            (list) => list.where((r) => r.projectId == projectId).toList(),
          ),
    );

/// A single visible report, or `null` if it doesn't exist / isn't visible.
final reportByIdProvider = Provider.family<AsyncValue<Report?>, String>(
  (ref, id) => ref
      .watch(reportsProvider)
      .whenData((list) => list.where((r) => r.id == id).firstOrNull),
);

class ReportsNotifier extends AsyncNotifier<List<Report>> {
  @override
  Future<List<Report>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];

    final visibleProjectIds = (await ref.watch(projectsProvider.future))
        .map((p) => p.id)
        .toSet();

    final repo = ref.watch(reportRepositoryProvider);
    final result = await repo.getReports();
    return result.when(
      success: (reports) => reports
          .where((r) => visibleProjectIds.contains(r.projectId))
          .toList(),
      failure: (f) => throw f,
    );
  }

  Future<Result<Report>> submitReport({
    required String projectId,
    required String text,
    required List<CompressedPhoto> photos,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      return const Err(
        Failure(FailureCode.sessionExpired, message: 'No signed-in user'),
      );
    }

    final List<Project> projects;
    try {
      projects = await ref.read(projectsProvider.future);
    } on Failure catch (f) {
      return Err(f);
    }
    final project = projects.where((p) => p.id == projectId).firstOrNull;
    if (project == null) {
      return Err(
        Failure(
          FailureCode.notFound,
          message: 'Project $projectId is not visible to ${user.id}',
        ),
      );
    }

    final repo = ref.read(reportRepositoryProvider);
    final result = await repo.submitReport(
      projectId: projectId,
      projectName: project.name,
      authorId: user.id,
      authorName: user.name,
      text: text,
      photos: photos,
    );
    if (result.isSuccess) ref.invalidateSelf();
    return result;
  }
}

// ── Today ─────────────────────────────────────────────────────

bool _isToday(DateTime date, DateTime now) =>
    date.year == now.year && date.month == now.month && date.day == now.day;

/// Time of today's latest report for a project, or `null` if there is none.
final todayReportTimeProvider = Provider.family<DateTime?, String>((
  ref,
  projectId,
) {
  final reports = ref.watch(reportsProvider).valueOrNull ?? const [];
  final now = DateTime.now();
  DateTime? latest;
  for (final r in reports) {
    if (r.projectId != projectId || !_isToday(r.createdAt, now)) continue;
    if (latest == null || r.createdAt.isAfter(latest)) latest = r.createdAt;
  }
  return latest;
});

/// Day summary on the projects screen, over the visible projects.
typedef DaySummary = ({
  /// Active projects with at least one report today.
  int reportsSent,

  /// Active projects.
  int activeProjects,

  /// Photos in today's reports.
  int newPhotos,
});

final daySummaryProvider = Provider<AsyncValue<DaySummary>>((ref) {
  final projects = ref.watch(projectsProvider);
  // Until reports load every project would look like it has no report.
  final reports = ref.watch(reportsProvider).valueOrNull;
  if (reports == null) return const AsyncLoading();
  return projects.whenData((list) {
    final now = DateTime.now();
    final today = reports.where((r) => _isToday(r.createdAt, now)).toList();
    final reported = today.map((r) => r.projectId).toSet();
    final active = list.where((p) => p.status.isActive);
    return (
      reportsSent: active.where((p) => reported.contains(p.id)).length,
      activeProjects: active.length,
      newPhotos: today.fold(0, (sum, r) => sum + r.photos.length),
    );
  });
});

/// Cover of a project page: the last photo of the project's latest report
/// with photos, or `null` if there are none.
final projectCoverProvider = Provider.family<String?, String>((ref, projectId) {
  final reports = ref.watch(projectReportsProvider(projectId)).valueOrNull;
  Report? latest;
  for (final r in reports ?? const <Report>[]) {
    if (r.photos.isEmpty) continue;
    if (latest == null || r.createdAt.isAfter(latest.createdAt)) latest = r;
  }
  return latest?.photos.last.url;
});
