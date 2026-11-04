import 'package:buildflow/core/utils/date_formatter.dart';
import 'package:buildflow/features/reports/domain/entities/report.dart';
import 'package:buildflow/features/reports/domain/report_days.dart';
import 'package:flutter_test/flutter_test.dart';

Report _report(String id, DateTime at) => Report(
      id: id,
      projectId: 'project-1',
      projectName: 'Объект',
      authorId: 'user-foreman-1',
      authorName: 'Бакыт',
      text: id,
      photos: const [],
      createdAt: at,
    );

void main() {
  tearDown(() => DateFormatter.debugUtcOffset = null);

  // Newest first, as the server sends them.
  final reports = [
    _report('b', DateTime.utc(2026, 11, 4, 5)),
    _report('c', DateTime.utc(2026, 11, 3, 20, 30)),
    _report('d', DateTime.utc(2026, 11, 3, 18)),
    _report('e', DateTime.utc(2026, 11, 3, 17, 59)),
  ];

  /// «4.11: bcd»: the day, then its reports in order.
  List<String> grouped() => [
        for (final day in groupReportsByDay(reports))
          '${day.day.day}.${day.day.month}: ${day.reports.map((r) => r.id).join()}',
      ];

  test('at +6 the hours 00:00–05:59 belong to the new local day', () {
    DateFormatter.debugUtcOffset = const Duration(hours: 6);
    expect(grouped(), ['4.11: bcd', '3.11: e']);
  });

  test('at -5 the same moments fall on other local days', () {
    DateFormatter.debugUtcOffset = const Duration(hours: -5);
    expect(grouped(), ['4.11: b', '3.11: cde']);
  });

  test('the day is a calendar date at midnight', () {
    DateFormatter.debugUtcOffset = const Duration(hours: 6);
    expect(groupReportsByDay(reports).first.day, DateTime(2026, 11, 4));
  });

  test('no reports, no days', () {
    expect(groupReportsByDay(const []), isEmpty);
  });
}
