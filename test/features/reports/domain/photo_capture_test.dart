import 'package:buildflow/core/utils/date_formatter.dart';
import 'package:buildflow/features/reports/domain/entities/report_photo.dart';
import 'package:buildflow/features/reports/domain/photo_capture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final reportedAt = DateTime(2026, 10, 28, 17, 5);
  ReportPhoto takenAt(DateTime? at) =>
      ReportPhoto(id: 'p', url: 'fake:p', takenAt: at);

  test('a photo of the report day is not flagged', () {
    expect(takenOnAnotherDay(takenAt(DateTime(2026, 10, 28, 8)), reportedAt),
        isFalse);
    expect(
      takenOnAnotherDay(takenAt(DateTime(2026, 10, 28, 23, 59)), reportedAt),
      isFalse,
    );
  });

  test('a photo of an earlier or later day is flagged', () {
    expect(
      takenOnAnotherDay(takenAt(DateTime(2026, 10, 27, 23, 59)), reportedAt),
      isTrue,
    );
    expect(takenOnAnotherDay(takenAt(DateTime(2025, 10, 28, 12)), reportedAt),
        isTrue);
  });

  test('days are compared in local time', () {
    final local = DateTime(2026, 10, 28, 0, 30);
    expect(takenOnAnotherDay(takenAt(local.toUtc()), reportedAt), isFalse);
  });

  test('a photo without a capture time is not flagged', () {
    expect(takenOnAnotherDay(takenAt(null), reportedAt), isFalse);
  });

  test('the day boundary follows the phone time zone', () {
    addTearDown(() => DateFormatter.debugUtcOffset = null);
    final photo = takenAt(DateTime.utc(2026, 11, 3, 17, 59));
    final sent = DateTime.utc(2026, 11, 3, 18);

    // 23:59 and 00:00 of the next day.
    DateFormatter.debugUtcOffset = const Duration(hours: 6);
    expect(takenOnAnotherDay(photo, sent), isTrue);
    // 12:59 and 13:00 of one day.
    DateFormatter.debugUtcOffset = const Duration(hours: -5);
    expect(takenOnAnotherDay(photo, sent), isFalse);
  });
}
