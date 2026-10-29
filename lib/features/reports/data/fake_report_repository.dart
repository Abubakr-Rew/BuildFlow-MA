import 'dart:math';

import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/photos/compressed_photo.dart';
import 'package:buildflow/features/reports/domain/entities/draft_report.dart';
import 'package:buildflow/features/reports/domain/entities/report.dart';
import 'package:buildflow/features/reports/domain/entities/report_photo.dart';
import 'package:buildflow/features/reports/domain/repositories/report_repository.dart';

/// In-memory fake report repository with seeded demo data.
class FakeReportRepository implements ReportRepository {
  FakeReportRepository({this.companyId = 'company-1'});

  final String companyId;
  final _random = Random();
  final List<DraftReport> _drafts = [];

  final List<Report> _reports = [
    Report(
      id: 'report-1',
      projectId: 'project-1',
      projectName: 'ЖК «Ала-Тоо Резиденс»',
      authorId: 'user-foreman-1',
      authorName: 'Бакыт Касымов',
      text: 'Залили фундамент блока Б. Бетон марки М300, '
          'всего 42 кубометра. Опалубку снимем через 3 дня.',
      photos: [
        const ReportPhoto(id: 'photo-1', url: 'fake:foundation-1'),
        const ReportPhoto(id: 'photo-2', url: 'fake:foundation-2'),
        const ReportPhoto(id: 'photo-3', url: 'fake:foundation-3'),
      ],
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    Report(
      id: 'report-2',
      projectId: 'project-2',
      projectName: 'Коттеджный посёлок «Горный»',
      authorId: 'user-foreman-2',
      authorName: 'Данияр Жумабеков',
      text: 'Закончили кладку стен 1-го этажа дома №5. '
          'Использовали кирпич 250×120×65. Завтра начнём перемычки.',
      photos: [
        const ReportPhoto(id: 'photo-4', url: 'fake:brickwork-1'),
        const ReportPhoto(id: 'photo-5', url: 'fake:brickwork-2'),
      ],
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    Report(
      id: 'report-3',
      projectId: 'project-1',
      projectName: 'ЖК «Ала-Тоо Резиденс»',
      authorId: 'user-foreman-1',
      authorName: 'Бакыт Касымов',
      text: 'Установили арматурный каркас для колонн 2-го этажа. '
          'Диаметр 16мм, шаг 200мм. Готовы к заливке.',
      photos: [
        const ReportPhoto(id: 'photo-6', url: 'fake:rebar-1'),
        const ReportPhoto(id: 'photo-7', url: 'fake:rebar-2'),
        const ReportPhoto(id: 'photo-8', url: 'fake:rebar-3'),
        const ReportPhoto(id: 'photo-9', url: 'fake:rebar-4'),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
    ),
    Report(
      id: 'report-4',
      projectId: 'project-2',
      projectName: 'Коттеджный посёлок «Горный»',
      authorId: 'user-foreman-1',
      authorName: 'Бакыт Касымов',
      text: 'Завезли пиломатериал для стропильной системы дома №3. '
          'Брус 150×200, доска 50×150. Разгрузка и складирование завершены.',
      photos: [
        const ReportPhoto(id: 'photo-10', url: 'fake:lumber-1'),
        const ReportPhoto(id: 'photo-11', url: 'fake:lumber-2'),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 6)),
    ),
    Report(
      id: 'report-5',
      projectId: 'project-3',
      projectName: 'Офис «Байтик»',
      authorId: 'user-foreman-2',
      authorName: 'Данияр Жумабеков',
      text: 'Штукатурка стен 2-го этажа завершена на 80%. '
          'Завтра закончим оставшуюся часть и приступим к потолкам.',
      photos: [
        const ReportPhoto(id: 'photo-12', url: 'fake:plaster-1'),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 4)),
    ),
  ];

  Future<void> _simulateLatency() async {
    final ms = 200 + _random.nextInt(400);
    await Future<void>.delayed(Duration(milliseconds: ms));
  }

  @override
  Future<Result<List<Report>>> getReports() async {
    await _simulateLatency();
    final sorted = List<Report>.from(_reports)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Success(sorted);
  }

  @override
  Future<Result<List<Report>>> getReportsByProject(String projectId) async {
    await _simulateLatency();
    final filtered = _reports
        .where((r) => r.projectId == projectId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Success(filtered);
  }

  @override
  Future<Result<Report>> getReport(String id) async {
    await _simulateLatency();
    final report = _reports.where((r) => r.id == id).firstOrNull;
    if (report == null) {
      return Err(
        Failure(FailureCode.notFound, message: 'Report $id not found'),
      );
    }
    return Success(report);
  }

  @override
  Future<Result<Report>> submitReport({
    required String projectId,
    required String projectName,
    required String authorId,
    required String authorName,
    required String text,
    required List<CompressedPhoto> photos,
  }) async {
    await _simulateLatency();
    final now = DateTime.now();
    final report = Report(
      id: 'report-${DateTime.now().millisecondsSinceEpoch}',
      projectId: projectId,
      projectName: projectName,
      authorId: authorId,
      authorName: authorName,
      text: text,
      // The compressed copies stay where they are and serve as the
      // «uploaded» photos. A report without photos gets a demo one, so the
      // demo always has something to show.
      photos: [
        for (final photo in photos)
          ReportPhoto(
            id: 'photo-${now.millisecondsSinceEpoch}-'
                '${_random.nextInt(100000)}',
            url: photo.path,
          ),
        if (photos.isEmpty)
          ReportPhoto(
            id: 'photo-${now.millisecondsSinceEpoch}',
            url: 'fake:demo-${now.millisecondsSinceEpoch}',
          ),
      ],
      createdAt: now,
    );
    _reports.insert(0, report);
    return Success(report);
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
  Future<Result<List<DraftReport>>> getDrafts() async {
    return Success(List.unmodifiable(_drafts));
  }

  @override
  Future<Result<void>> deleteDraft(String draftId) async {
    _drafts.removeWhere((d) => d.id == draftId);
    return const Success(null);
  }
}
