import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/photos/compressed_photo.dart';
import 'package:buildflow/core/utils/date_formatter.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/projects/data/fake_project_repository.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/presentation/providers/project_provider.dart';
import 'package:buildflow/features/reports/data/fake_report_repository.dart';
import 'package:buildflow/features/reports/domain/entities/report.dart';
import 'package:buildflow/features/reports/domain/entities/report_photo.dart';
import 'package:buildflow/features/reports/presentation/providers/report_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _foreman = User(
  id: 'user-foreman-1',
  email: 'foreman1@buildflow.kg',
  name: 'Бакыт Касымов',
  role: UserRole.foreman,
  companyId: 'company-1',
);

class _FailingReports extends FakeReportRepository {
  _FailingReports(this.failure);

  final Failure failure;

  @override
  Future<Result<Report>> submitReport({
    required String projectId,
    required String projectName,
    required String authorId,
    required String authorName,
    required String text,
    required List<CompressedPhoto> photos,
  }) async => Err(failure);
}

class _UnloadableProjects extends FakeProjectRepository {
  @override
  Future<Result<List<Project>>> getProjects() async =>
      const Err(Failure(FailureCode.timeout));
}

void main() {
  ProviderContainer container({
    User? user = _foreman,
    List<Override> overrides = const [],
  }) {
    final c = ProviderContainer(
      overrides: [currentUserProvider.overrideWithValue(user), ...overrides],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<Result<Report>> submit(ProviderContainer c, {String? projectId}) => c
      .read(reportsProvider.notifier)
      .submitReport(
        projectId: projectId ?? 'project-1',
        text: 'Залили фундамент',
        photos: const [],
      );

  group('ReportsNotifier.submitReport', () {
    test('returns the new report and reloads the list', () async {
      final c = container();
      final result = await submit(c);
      expect(result.value.text, 'Залили фундамент');

      final reports = await c.read(reportsProvider.future);
      expect(reports.map((r) => r.id), contains(result.value.id));
    });

    test('passes the repository failure through with its code', () async {
      final c = container(
        overrides: [
          reportRepositoryProvider.overrideWithValue(
            _FailingReports(const Failure(FailureCode.network)),
          ),
        ],
      );
      expect((await submit(c)).failure.code, FailureCode.network);
    });

    test('fails with sessionExpired without a signed-in user', () async {
      final c = container(user: null);
      expect((await submit(c)).failure.code, FailureCode.sessionExpired);
    });

    test('fails with notFound for a project the user cannot see', () async {
      // project-3 belongs to foreman 2.
      final c = container();
      final result = await submit(c, projectId: 'project-3');
      expect(result.failure.code, FailureCode.notFound);
    });

    test('returns the projects failure instead of throwing', () async {
      final c = container(
        overrides: [
          projectRepositoryProvider.overrideWithValue(_UnloadableProjects()),
        ],
      );
      expect((await submit(c)).failure.code, FailureCode.timeout);
    });
  });
  group("today on the phone's clock", () {
    tearDown(() => DateFormatter.debugUtcOffset = null);

    Report at(String id, DateTime time, {int photos = 0}) => Report(
          id: id,
          projectId: 'project-1',
          projectName: 'ЖК «Ала-Тоо Резиденс»',
          authorId: 'user-foreman-1',
          authorName: 'Бакыт Касымов',
          text: id,
          photos: [
            for (var i = 0; i < photos; i++)
              ReportPhoto(id: '$id-$i', url: 'fake:$id-$i'),
          ],
          createdAt: time,
        );

    /// The moment today began on the phone's clock, [offset] from UTC.
    DateTime midnight(Duration offset) {
      final clock = DateFormatter.local(DateTime.now());
      return DateTime.utc(clock.year, clock.month, clock.day).subtract(offset);
    }

    for (final (name, offset) in const [
      ('+6', Duration(hours: 6)),
      ('-5', Duration(hours: -5)),
    ]) {
      test('at $name the night hours count as today', () async {
        DateFormatter.debugUtcOffset = offset;
        final start = midnight(offset);
        final latest = start.add(const Duration(hours: 5, minutes: 59));
        final c = container(
          overrides: [
            reportRepositoryProvider.overrideWithValue(
              _FixedReports([
                at('early', latest, photos: 2),
                at('midnight', start, photos: 1),
                at(
                  'yesterday',
                  start.subtract(const Duration(minutes: 1)),
                  photos: 5,
                ),
              ]),
            ),
          ],
        );

        await c.read(projectsProvider.future);
        await c.read(reportsProvider.future);

        expect(c.read(todayReportTimeProvider('project-1')), latest);
        final summary = c.read(daySummaryProvider).requireValue;
        expect(summary.reportsSent, 1);
        expect(summary.newPhotos, 3);
      });

      test("at $name a minute before midnight isn't today", () async {
        DateFormatter.debugUtcOffset = offset;
        final c = container(
          overrides: [
            reportRepositoryProvider.overrideWithValue(
              _FixedReports([
                at(
                  'yesterday',
                  midnight(offset).subtract(const Duration(minutes: 1)),
                ),
              ]),
            ),
          ],
        );

        await c.read(reportsProvider.future);

        expect(c.read(todayReportTimeProvider('project-1')), isNull);
      });
    }
  });

  group('projectCoverProvider', () {
    test('is the last photo of the latest report with photos', () async {
      final now = DateTime.now();
      Report report(String id, Duration ago, List<String> photos) => Report(
        id: id,
        projectId: 'project-1',
        projectName: 'ЖК «Ала-Тоо Резиденс»',
        authorId: 'user-foreman-1',
        authorName: 'Бакыт Касымов',
        text: 'Работы',
        photos: [for (final p in photos) ReportPhoto(id: '$id-$p', url: p)],
        createdAt: now.subtract(ago),
      );
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(_foreman),
          reportRepositoryProvider.overrideWithValue(
            _FixedReports([
              report('old', const Duration(days: 2), ['fake:a']),
              report('new', const Duration(hours: 3), ['fake:b', 'fake:c']),
              report('text-only', const Duration(hours: 1), []),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(reportsProvider.future);
      expect(container.read(projectCoverProvider('project-1')), 'fake:c');
      // Visible to the foreman, but no reports at all.
      expect(container.read(projectCoverProvider('project-2')), isNull);
    });
  });
}

class _FixedReports extends FakeReportRepository {
  _FixedReports(this.reports);

  final List<Report> reports;

  @override
  Future<Result<List<Report>>> getReports() async => Success(reports);
}
