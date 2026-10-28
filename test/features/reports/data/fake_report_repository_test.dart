import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/features/reports/data/fake_report_repository.dart';
import 'package:buildflow/features/reports/domain/entities/draft_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeReportRepository repo;

  setUp(() {
    repo = FakeReportRepository();
  });

  group('FakeReportRepository', () {
    test('getReports returns seeded data sorted by date', () async {
      final result = await repo.getReports();
      expect(result.isSuccess, isTrue);
      expect(result.value.length, 5);
      // Verify sorted newest first
      for (var i = 0; i < result.value.length - 1; i++) {
        expect(
          result.value[i].createdAt.isAfter(result.value[i + 1].createdAt),
          isTrue,
        );
      }
    });

    test('getReportsByProject filters correctly', () async {
      final result = await repo.getReportsByProject('project-1');
      expect(result.isSuccess, isTrue);
      for (final report in result.value) {
        expect(report.projectId, 'project-1');
      }
    });

    test('getReport returns correct report', () async {
      final result = await repo.getReport('report-1');
      expect(result.isSuccess, isTrue);
      expect(result.value.photos, isNotEmpty);
    });

    test('getReport fails for unknown id', () async {
      final result = await repo.getReport('nonexistent');
      expect(result.failure.code, FailureCode.notFound);
    });

    test('submitReport adds a new report', () async {
      final result = await repo.submitReport(
        projectId: 'project-1',
        projectName: 'ЖК «Ала-Тоо Резиденс»',
        authorId: 'user-foreman-1',
        authorName: 'Бакыт Касымов',
        text: 'Тестовый отчёт',
        photoPaths: ['path1', 'path2'],
      );
      expect(result.isSuccess, isTrue);
      expect(result.value.text, 'Тестовый отчёт');
      expect(result.value.photos.length, 2);
      expect(result.value.authorName, 'Бакыт Касымов');

      // Verify it appears first in list (newest)
      final all = await repo.getReports();
      expect(all.value.first.text, 'Тестовый отчёт');
    });

    test('saveDraft and getDrafts work correctly', () async {
      final draft = DraftReport(
        id: 'draft-1',
        projectId: 'project-1',
        projectName: 'Тест',
        text: 'Черновик',
        photoPaths: [],
        createdAt: DateTime.now(),
      );
      await repo.saveDraft(draft);

      final drafts = await repo.getDrafts();
      expect(drafts.isSuccess, isTrue);
      expect(drafts.value.length, 1);
      expect(drafts.value.first.text, 'Черновик');
    });

    test('deleteDraft removes draft', () async {
      final draft = DraftReport(
        id: 'draft-1',
        projectId: 'project-1',
        projectName: 'Тест',
        text: 'Delete me',
        photoPaths: [],
        createdAt: DateTime.now(),
      );
      await repo.saveDraft(draft);
      await repo.deleteDraft('draft-1');

      final drafts = await repo.getDrafts();
      expect(drafts.value, isEmpty);
    });
  });
}
