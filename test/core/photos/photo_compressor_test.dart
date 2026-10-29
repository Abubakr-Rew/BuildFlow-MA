import 'package:buildflow/core/config.dart';
import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/photos/compressed_photo.dart';
import 'package:buildflow/core/photos/photo_compressor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const compressor = PlatformPhotoCompressor();
  final calls = <MethodCall>[];

  /// Answers the channel like PhotoCompressor.kt would.
  void answer(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PlatformPhotoCompressor.channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  setUp(calls.clear);
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PlatformPhotoCompressor.channel, null),
  );

  group('compress', () {
    test('asks for the configured size, budget and quality steps', () async {
      answer((_) async => {
            'path': '/cache/photos/a.jpg',
            'width': 1600,
            'height': 1200,
            'bytes': 380000,
            'quality': 82,
          });
      await compressor.compress('/cache/image_picker123.jpg');

      expect(calls.single.method, 'compress');
      expect(calls.single.arguments, {
        'path': '/cache/image_picker123.jpg',
        'maxSide': 1600,
        'targetBytes': 450 * 1024,
        'qualities': [82, 74, 66],
      });
      expect(kPhotoMaxSide, 1600);
      expect(kPhotoTargetBytes, 460800);
      expect(kPhotoQualitySteps, [82, 74, 66]);
    });

    test('returns the copy with its size and capture time', () async {
      answer((_) async => {
            'path': '/cache/photos/a.jpg',
            'width': 1200,
            'height': 1600,
            'bytes': 410000,
            'quality': 74,
            'takenAt': '2026:10:28 11:42:05',
            'takenAtOffset': '+06:00',
          });
      final result = await compressor.compress('/cache/x.jpg');
      expect(
        result.value,
        CompressedPhoto(
          path: '/cache/photos/a.jpg',
          width: 1200,
          height: 1600,
          bytes: 410000,
          takenAt: DateTime.utc(2026, 10, 28, 5, 42, 5),
        ),
      );
    });

    test('a photo without a capture time has none', () async {
      answer((_) async => {
            'path': '/cache/photos/a.jpg',
            'width': 1600,
            'height': 900,
            'bytes': 200000,
            'quality': 82,
            'takenAt': null,
          });
      final result = await compressor.compress('/cache/screenshot.png');
      expect(result.value.takenAt, isNull);
    });

    test('a native failure becomes photoProcessing, never an exception',
        () async {
      answer(
        (_) async => throw PlatformException(
          code: 'unsupported_format',
          message: 'Cannot decode image/heif',
        ),
      );
      final result = await compressor.compress('/cache/IMG_1.heic');
      expect(result.failure.code, FailureCode.photoProcessing);
      expect(result.failure.message, contains('unsupported_format'));
    });

    test('a malformed reply is a photoProcessing failure', () async {
      answer((_) async => {'path': '/cache/photos/a.jpg'});
      final result = await compressor.compress('/cache/x.jpg');
      expect(result.failure.code, FailureCode.photoProcessing);
    });

    test('without the native side it fails the same way', () async {
      // No handler: MissingPluginException, as on a platform without it.
      final result = await compressor.compress('/cache/x.jpg');
      expect(result, isA<Err<CompressedPhoto>>());
      expect(result.failure.code, FailureCode.photoProcessing);
    });
  });

  group('delete and sweep', () {
    test('delete skips demo and network photos', () async {
      answer((_) async => null);
      await compressor.delete([
        '/cache/a.jpg',
        'fake:demo-1',
        'https://storage.buildflow.kg/b.jpg',
      ]);
      expect(calls.single.arguments, {
        'paths': ['/cache/a.jpg'],
      });

      calls.clear();
      await compressor.delete(['fake:demo-2']);
      expect(calls, isEmpty);
    });

    test('sweep passes the age and swallows failures', () async {
      answer((_) async => throw PlatformException(code: 'failed'));
      await compressor.sweep();
      expect(calls.single.method, 'sweep');
      expect(calls.single.arguments, {'olderThanMs': 24 * 3600 * 1000});
    });
  });

  group('parseExifDateTime', () {
    test('reads the time at its offset as an instant', () {
      expect(
        parseExifDateTime('2026:10:28 11:42:05', '+06:00'),
        DateTime.utc(2026, 10, 28, 5, 42, 5),
      );
      expect(
        parseExifDateTime('2026:10:28 01:00:00', '-03:30'),
        DateTime.utc(2026, 10, 28, 4, 30),
      );
    });

    test('without an offset it is the local time of the phone', () {
      expect(
        parseExifDateTime('2026:10:28 11:42:05'),
        DateTime(2026, 10, 28, 11, 42, 5),
      );
      expect(
        parseExifDateTime('2026:10:28 11:42:05', 'garbage'),
        DateTime(2026, 10, 28, 11, 42, 5),
      );
    });

    test('missing, blank or impossible values are null', () {
      for (final value in [
        null,
        '',
        '    :  :     :  :  ',
        '0000:00:00 00:00:00',
        '2026:13:01 10:00:00',
        '2026:10:28 25:00:00',
        '28.10.2026 11:42',
      ]) {
        expect(parseExifDateTime(value), isNull, reason: '$value');
      }
    });
  });
}
