import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/photos/compressed_photo.dart';
import 'package:buildflow/core/photos/photo_compressor.dart';

/// [PhotoCompressor] for tests: «compresses» `x.jpg` into `x.jpg.small.jpg`
/// after [delay] and records every call.
class FakePhotoCompressor implements PhotoCompressor {
  FakePhotoCompressor({
    this.delay = const Duration(milliseconds: 10),
    this.takenAt,
    Set<String>? failing,
  }) : failing = failing ?? {};

  final Duration delay;
  final DateTime? takenAt;

  /// Originals that fail to compress, until removed from the set.
  final Set<String> failing;

  final List<String> compressed = [];
  final List<String> deleted = [];
  int sweeps = 0;

  static String copyOf(String sourcePath) => '$sourcePath.small.jpg';

  @override
  Future<Result<CompressedPhoto>> compress(String sourcePath) async {
    compressed.add(sourcePath);
    await Future<void>.delayed(delay);
    if (failing.contains(sourcePath)) {
      return const Err(
        Failure(FailureCode.photoProcessing, message: 'Test failure'),
      );
    }
    return Success(
      CompressedPhoto(
        path: copyOf(sourcePath),
        width: 1600,
        height: 1200,
        bytes: 300 * 1024,
        takenAt: takenAt,
      ),
    );
  }

  @override
  Future<void> delete(Iterable<String> paths) async => deleted.addAll(paths);

  @override
  Future<void> sweep({Duration olderThan = const Duration(hours: 24)}) async =>
      sweeps++;
}
