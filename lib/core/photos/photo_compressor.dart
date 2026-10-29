import 'package:buildflow/core/config.dart';
import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/photos/compressed_photo.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Compresses picked photos before they are sent with a report or a chat
/// message. Never throws.
abstract class PhotoCompressor {
  /// A copy of the photo at [sourcePath]: at most [kPhotoMaxSide] px on the
  /// long side, upright, JPEG without EXIF, aiming at [kPhotoTargetBytes].
  /// The original stays where it is. A failure is
  /// [FailureCode.photoProcessing].
  Future<Result<CompressedPhoto>> compress(String sourcePath);

  /// Deletes picked originals and compressed copies once they are no
  /// longer needed. Only files in the app cache are touched.
  Future<void> delete(Iterable<String> paths);

  /// Deletes copies and picker leftovers older than [olderThan]. Called
  /// once after the app starts: what is pending lives in memory only, so
  /// nothing from an earlier run is still needed.
  Future<void> sweep({Duration olderThan = const Duration(hours: 24)});
}

/// [PhotoCompressor] over the `buildflow/photos` platform channel, Android
/// only for now (android/app/src/main/kotlin/…/PhotoCompressor.kt). Elsewhere
/// every call fails with [FailureCode.photoProcessing].
class PlatformPhotoCompressor implements PhotoCompressor {
  const PlatformPhotoCompressor();

  static const channel = MethodChannel('buildflow/photos');

  @override
  Future<Result<CompressedPhoto>> compress(String sourcePath) async {
    final watch = Stopwatch()..start();
    try {
      final reply = await channel.invokeMapMethod<String, Object?>(
        'compress',
        {
          'path': sourcePath,
          'maxSide': kPhotoMaxSide,
          'targetBytes': kPhotoTargetBytes,
          'qualities': kPhotoQualitySteps,
        },
      );
      final photo = _photoFrom(reply);
      if (photo == null) {
        return Err(
          Failure(
            FailureCode.photoProcessing,
            message: 'Malformed compress reply: $reply',
          ),
        );
      }
      // For checking speed and size on a device: `flutter logs`.
      debugPrint(
        'Photo compressed in ${watch.elapsedMilliseconds} ms: '
        '${photo.width}×${photo.height}, ${photo.bytes ~/ 1024} KB, '
        'quality ${reply!['quality']}',
      );
      return Success(photo);
    } on PlatformException catch (e, stackTrace) {
      return Err(
        Failure(
          FailureCode.photoProcessing,
          message: '${e.code}: ${e.message}',
          stackTrace: stackTrace,
        ),
      );
    } on MissingPluginException catch (e, stackTrace) {
      return Err(
        Failure(
          FailureCode.photoProcessing,
          message: 'No photo compressor on this platform: $e',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  static CompressedPhoto? _photoFrom(Map<String, Object?>? reply) {
    if (reply == null) return null;
    final path = reply['path'];
    final width = reply['width'];
    final height = reply['height'];
    final bytes = reply['bytes'];
    if (path is! String || width is! int || height is! int || bytes is! int) {
      return null;
    }
    return CompressedPhoto(
      path: path,
      width: width,
      height: height,
      bytes: bytes,
      takenAt: parseExifDateTime(
        reply['takenAt'] as String?,
        reply['takenAtOffset'] as String?,
      ),
    );
  }

  @override
  Future<void> delete(Iterable<String> paths) async {
    // Demo photos (`fake:`) and network ones are not files.
    final files = [
      for (final p in paths)
        if (!p.startsWith('fake:') && !p.startsWith('http')) p,
    ];
    if (files.isEmpty) return;
    await _quietly('delete', {'paths': files});
  }

  @override
  Future<void> sweep({Duration olderThan = const Duration(hours: 24)}) =>
      _quietly('sweep', {'olderThanMs': olderThan.inMilliseconds});

  /// Cleanup is best effort: a file left behind is swept on a later start.
  static Future<void> _quietly(String method, Map<String, Object?> args) async {
    try {
      await channel.invokeMethod<void>(method, args);
    } on PlatformException catch (e) {
      debugPrint('Photo $method failed: ${e.code} ${e.message}');
    } on MissingPluginException {
      // Not Android: nothing was written to clean up.
    }
  }
}
