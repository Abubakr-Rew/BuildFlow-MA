import 'package:freezed_annotation/freezed_annotation.dart';

part 'report_photo.freezed.dart';
part 'report_photo.g.dart';

@freezed
abstract class ReportPhoto with _$ReportPhoto {
  const factory ReportPhoto({
    required String id,
    /// URL or local path. Fake photos use 'fake:N' scheme.
    required String url,
    String? thumbnailUrl,
  }) = _ReportPhoto;

  factory ReportPhoto.fromJson(Map<String, dynamic> json) =>
      _$ReportPhotoFromJson(json);
}
