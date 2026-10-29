import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/core/widgets/photo_thumbnail.dart';
import 'package:buildflow/core/widgets/photo_viewer.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/reports/presentation/screens/report_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/test_app.dart';

const _owner = User(
  id: 'user-owner-1',
  email: 'owner@buildflow.kg',
  name: 'Асан Бекович',
  role: UserRole.owner,
  companyId: 'company-1',
);

void main() {
  final l10n = AppLocalizationsRu();

  Future<void> openReport(WidgetTester tester, String id) async {
    await pumpTestApp(
      tester,
      ReportDetailScreen(reportId: id),
      overrides: [currentUserProvider.overrideWithValue(_owner)],
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<void> tapPhoto(WidgetTester tester, int index) async {
    await tester.ensureVisible(find.byType(PhotoThumbnail).at(index));
    await tester.tap(find.byType(PhotoThumbnail).at(index));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a photo opens the viewer on that photo, with when it was shot',
      (tester) async {
    await openReport(tester, 'report-2');
    await tapPhoto(tester, 0);

    expect(find.byType(PhotoViewer), findsOneWidget);
    expect(find.text(l10n.photoOf(1, 2)), findsOneWidget);
    // «Данияр Жумабеков · Снято 11:42»: the seeded shot is of that day.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            RegExp(
              '^Данияр Жумабеков · ${l10n.photoTakenAt(r'\d{2}:\d{2}')}\$',
            ).hasMatch(w.data ?? ''),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.photoTakenNotToday), findsNothing);
  });

  testWidgets('an old photo is flagged «Снято не сегодня»', (tester) async {
    await openReport(tester, 'report-2');
    await tapPhoto(tester, 1);

    expect(find.text(l10n.photoOf(2, 2)), findsOneWidget);
    expect(find.text(l10n.photoTakenNotToday), findsOneWidget);
  });

  testWidgets('swiping sideways shows the next photo; the cross closes',
      (tester) async {
    await openReport(tester, 'report-3');
    await tapPhoto(tester, 1);
    expect(find.text(l10n.photoOf(2, 4)), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text(l10n.photoOf(3, 4)), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.photoViewerClose));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewer), findsNothing);
  });

  testWidgets('swiping down closes the viewer', (tester) async {
    await openReport(tester, 'report-3');
    await tapPhoto(tester, 0);

    await tester.drag(find.byType(PageView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewer), findsNothing);
  });
}
