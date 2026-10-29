import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/photos/compressed_photo.dart';
import 'package:flutter/foundation.dart';

/// A picked photo on its way to a compressed copy: a tile with a spinner,
/// then the photo, or a red mark with «Повторить / Удалить».
@immutable
class PhotoDraft {
  const PhotoDraft({
    required this.id,
    required this.sourcePath,
    this.photo,
    this.failure,
  });

  final String id;

  /// The picked file, shown as the preview. Kept until the photo is sent
  /// or removed: a failed compression can be retried from it.
  final String sourcePath;

  /// The compressed copy, once ready.
  final CompressedPhoto? photo;

  /// Why compressing failed; the original is still there to retry.
  final Failure? failure;

  bool get isReady => photo != null;
  bool get isFailed => failure != null;
  bool get isProcessing => photo == null && failure == null;
}

/// A draft handed over to whatever sends it, with its compression, which
/// may still be running.
typedef PhotoHandoff = ({
  PhotoDraft draft,
  Future<Result<CompressedPhoto>> result,
});
