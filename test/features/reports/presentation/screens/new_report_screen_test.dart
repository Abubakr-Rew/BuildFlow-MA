import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/photos/compressed_photo.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/reports/data/fake_report_repository.dart';
import 'package:buildflow/features/reports/domain/entities/report.dart';
import 'package:buildflow/features/reports/presentation/providers/report_provider.dart';
import 'package:buildflow/features/reports/presentation/screens/new_report_screen.dart';
import 'package:flutter/material.dart';
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
    required List<CompressedPhoto> photos,
  }) async => Err(failure);
}

class _CountingReports extends FakeReportRepository {
  int submits = 0;

  @override
  Future<Result<Report>> submitReport({
    required String projectId,
    required String projectName,
    required String authorId,
    required String authorName,
    required String text,
    required List<CompressedPhoto> photos,
  }) {
    submits++;
    return super.submitReport(
      projectId: projectId,
      projectName: projectName,
      authorId: authorId,
      authorName: authorName,
      text: text,
      photos: photos,
    );
  }
}

void main() {
  final l10n = AppLocalizationsRu();

  group('appendTemplate', () {
    test('an empty text gets the word as is', () {
      expect(appendTemplate('', 'Бетон'), 'Бетон');
      expect(appendTemplate('  ', 'Бетон'), 'Бетон');
    });

    test('continues a phrase after a comma, in lower case', () {
      expect(
        appendTemplate('Залили фундамент ', 'Бетон'),
        'Залили фундамент, бетон',
      );
    });

    test('starts a new sentence after a full stop', () {
      expect(
        appendTemplate('Залили фундамент.', 'Нужны материалы'),
        'Залили фундамент. Нужны материалы',
      );
    });
  });

  group('NewReportScreen', () {
    testWidgets('a template chip appends its word to the text', (tester) async {
      await pumpTestApp(
        tester,
        const NewReportScreen(initialProjectId: 'project-1'),
        overrides: [currentUserProvider.overrideWithValue(_foreman)],
      );
      await tester.pump(const Duration(seconds: 1)); // projects load

      await tester.enterText(find.byType(TextFormField), 'Залили фундамент');
      await tester.tap(find.text(l10n.templateConcrete));
      await tester.pump();
      await tester.tap(find.text(l10n.templateMaterials));
      await tester.pump();

      expect(
        find.text('Залили фундамент, бетон, нужны материалы'),
        findsOneWidget,
      );
    });

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

    testWidgets('a double tap sends the report once', (tester) async {
      final reports = _CountingReports();
      await pumpTestApp(
        tester,
        const NewReportScreen(initialProjectId: 'project-1'),
        overrides: [
          currentUserProvider.overrideWithValue(_foreman),
          reportRepositoryProvider.overrideWithValue(reports),
        ],
      );
      await tester.pump(const Duration(seconds: 1)); // projects load

      await tester.enterText(find.byType(TextFormField), 'Залили фундамент');
      // No pump in between: both taps land before the button rebuilds.
      await tester.tap(find.text(l10n.sendReport));
      await tester.tap(find.text(l10n.sendReport));
      await tester.pump(const Duration(seconds: 1));

      expect(reports.submits, 1);
      expect(find.text(l10n.reportSent), findsOneWidget);

      await tester.pump(const Duration(seconds: 5)); // let the snackbar go
    });
  });
}
