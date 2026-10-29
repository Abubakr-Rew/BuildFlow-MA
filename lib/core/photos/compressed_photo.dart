import 'package:flutter/foundation.dart';

/// A photo ready to upload: a JPEG of at most `kPhotoMaxSide` px with no
/// EXIF, written to the app cache by `PhotoCompressor`.
@immutable
class CompressedPhoto {
  const CompressedPhoto({
    required this.path,
    required this.width,
    required this.height,
    required this.bytes,
    this.takenAt,
  });

  /// Local file of the compressed copy.
  final String path;

  /// Size in pixels, upright.
  final int width;
  final int height;

  /// File size.
  final int bytes;

  /// When the photo was taken, from the original's EXIF; `null` when the
  /// original didn't say (screenshots, photos from messengers).
  final DateTime? takenAt;

  @override
  bool operator ==(Object other) =>
      other is CompressedPhoto &&
      other.path == path &&
      other.width == width &&
      other.height == height &&
      other.bytes == bytes &&
      other.takenAt == takenAt;

  @override
  int get hashCode => Object.hash(path, width, height, bytes, takenAt);

  @override
  String toString() => 'CompressedPhoto($path, $width×$height, $bytes B)';
}

/// The capture time of EXIF `DateTimeOriginal` («2026:10:28 11:42:05»)
/// with `OffsetTimeOriginal` («+06:00»). Without the offset the time is
/// taken as the phone's local time. `null` for a missing, blank
/// («    :  :     :  :  ») or impossible value.
DateTime? parseExifDateTime(String? value, [String? offset]) {
  final match = RegExp(
    r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})',
  ).firstMatch(value?.trim() ?? '');
  if (match == null) return null;
  final [year, month, day, hour, minute, second] = [
    for (var i = 1; i <= 6; i++) int.parse(match.group(i)!),
  ];
  if (year < 1990 ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31 ||
      hour > 23 ||
      minute > 59 ||
      second > 59) {
    return null;
  }

  final zone = RegExp(r'^([+-])(\d{2}):(\d{2})$').firstMatch(offset?.trim() ?? '');
  if (zone == null) return DateTime(year, month, day, hour, minute, second);
  final sign = zone.group(1) == '-' ? -1 : 1;
  final shift = Duration(
    hours: int.parse(zone.group(2)!),
    minutes: int.parse(zone.group(3)!),
  );
  // Wall time at that offset → the same instant in UTC.
  return DateTime.utc(year, month, day, hour, minute, second)
      .subtract(shift * sign);
}
