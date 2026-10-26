import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/projects/data/fake_project_repository.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/presentation/providers/project_provider.dart';
import 'package:buildflow/features/reports/data/fake_report_repository.dart';
import 'package:buildflow/features/reports/domain/entities/report.dart';
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
    required List<String> photoPaths,
  }) async =>
      Err(failure);
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

  Future<Result<Report>> submit(ProviderContainer c, {String? projectId}) =>
      c.read(reportsProvider.notifier).submitReport(
            projectId: projectId ?? 'project-1',
            text: 'Залили фундамент',
            photoPaths: const ['fake:test'],
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
}
