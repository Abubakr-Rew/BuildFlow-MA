import 'package:buildflow/features/reports/domain/entities/report_photo.dart';

/// Whether [photo] was taken on another day than the report was sent at
/// [reportedAt], e.g. an old photo from the gallery. Days are the phone's
/// local ones. A photo that doesn't say when it was taken is not flagged:
/// screenshots and photos from messengers have no capture time.
bool takenOnAnotherDay(ReportPhoto photo, DateTime reportedAt) {
  final taken = photo.takenAt?.toLocal();
  if (taken == null) return false;
  final reported = reportedAt.toLocal();
  return taken.year != reported.year ||
      taken.month != reported.month ||
      taken.day != reported.day;
}
