import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/features/reports/presentation/screens/new_report_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsRu();

  group('describePhotoPickError', () {
    test('explains a refused camera permission and offers settings', () {
      final error = PlatformException(code: 'camera_access_denied');
      expect(
        describePhotoPickError(l10n, error),
        (message: l10n.cameraAccessDenied, offerSettings: true),
      );
    });

    test('explains a refused photo library permission and offers settings', () {
      final error = PlatformException(code: 'photo_access_denied');
      expect(
        describePhotoPickError(l10n, error),
        (message: l10n.photoAccessDenied, offerSettings: true),
      );
    });

    test('falls back to the generic text without settings', () {
      final noCamera = PlatformException(code: 'no_available_camera');
      for (final error in [noCamera, Exception('io')]) {
        expect(
          describePhotoPickError(l10n, error),
          (message: l10n.photoPickError, offerSettings: false),
        );
      }
    });
  });
}
