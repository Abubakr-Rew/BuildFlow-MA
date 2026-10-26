import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/reports/data/fake_report_repository.dart';
import 'package:buildflow/features/reports/domain/entities/report.dart';
import 'package:buildflow/features/reports/presentation/providers/report_provider.dart';
import 'package:buildflow/features/reports/presentation/screens/new_report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/test_app.dart';

const _foreman = User(
  id: 'user-foreman-1',
  email: 'foreman1@buildflow.kg',
  name: 'Бакыт Касымов',
  role: UserRole.foreman,
  companyId: 'company-1',
);

class _FailingReports extends FakeReportRepository {
  _FailingReports(this.failure);

  final Failure failure;

  @override
  Future<Result<Report>> submitReport({
    required String projectId,
    required String projectName,
    required String authorId,
    required String authorName,
    required String text,
    required List<String> photoPaths,
  }) async =>
      Err(failure);
}

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

  group('NewReportScreen', () {
    testWidgets('a failed submit says why and keeps the form', (tester) async {
      await pumpTestApp(
        tester,
        const NewReportScreen(initialProjectId: 'project-1'),
        overrides: [
          currentUserProvider.overrideWithValue(_foreman),
          reportRepositoryProvider.overrideWithValue(
            _FailingReports(const Failure(FailureCode.network)),
          ),
        ],
      );
      await tester.pump(const Duration(seconds: 1)); // projects load

      await tester.enterText(find.byType(TextFormField), 'Залили фундамент');
      await tester.tap(find.text(l10n.sendReport));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(l10n.reportError(l10n.errorNetwork)), findsOneWidget);
      expect(find.text('Залили фундамент'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5)); // let the snackbar go
    });
  });
}
