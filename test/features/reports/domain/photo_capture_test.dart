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
}
