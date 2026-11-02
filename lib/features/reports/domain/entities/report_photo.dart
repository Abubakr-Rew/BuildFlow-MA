import 'package:buildflow/core/remote_files/storage_ref.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'report_photo.freezed.dart';
part 'report_photo.g.dart';

@freezed
abstract class ReportPhoto with _$ReportPhoto {
  const factory ReportPhoto({
    required String id,
    /// URL or local path. Fake photos use 'fake:N' scheme; the server's
    /// photos are `storage:<bucket>/<path>` (`StorageRef`).
    @JsonKey(readValue: readStorageUrl) required String url,
    String? thumbnailUrl,

    /// When the photo was taken, from the original's EXIF; `null` if the
    /// photo didn't say. A photo taken on another day than the report is
    /// flagged in the viewer.
    DateTime? takenAt,
  }) = _ReportPhoto;

  factory ReportPhoto.fromJson(Map<String, dynamic> json) =>
      _$ReportPhotoFromJson(json);
}
