import 'package:buildflow/core/utils/date_formatter.dart';
import 'package:buildflow/features/reports/domain/entities/report.dart';
import 'package:flutter/foundation.dart';

/// The reports sent on one day of the phone's calendar.
@immutable
class ReportDay {
  const ReportDay({required this.day, required this.reports});

  /// Midnight of the day: a calendar date, not a moment.
  final DateTime day;
  final List<Report> reports;
}

/// [reports] by the phone's calendar day, latest day first; within a day
/// they keep their order.
List<ReportDay> groupReportsByDay(List<Report> reports) {
  final days = <DateTime, List<Report>>{};
  for (final report in reports) {
    days
        .putIfAbsent(DateFormatter.toDateOnly(report.createdAt), () => [])
        .add(report);
  }
  final sorted = days.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final day in sorted) ReportDay(day: day, reports: days[day]!),
  ];
}
