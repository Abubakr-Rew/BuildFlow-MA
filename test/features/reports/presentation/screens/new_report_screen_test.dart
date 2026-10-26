import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/features/reports/presentation/screens/new_report_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsRu();

  group('photoPickErrorText', () {
    test('explains a refused camera permission', () {
      final error = PlatformException(code: 'camera_access_denied');
      expect(photoPickErrorText(l10n, error), l10n.cameraAccessDenied);
    });

    test('explains a refused photo library permission', () {
      final error = PlatformException(code: 'photo_access_denied');
      expect(photoPickErrorText(l10n, error), l10n.photoAccessDenied);
    });

    test('falls back to the generic text for other failures', () {
      final noCamera = PlatformException(code: 'no_available_camera');
      expect(photoPickErrorText(l10n, noCamera), l10n.photoPickError);
      expect(photoPickErrorText(l10n, Exception('io')), l10n.photoPickError);
    });
  });
}
