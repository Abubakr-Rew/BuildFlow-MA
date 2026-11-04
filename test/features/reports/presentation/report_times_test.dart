import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/utils/date_formatter.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/projects/presentation/screens/project_list_screen.dart';
import 'package:buildflow/features/reports/data/fake_report_repository.dart';
import 'package:buildflow/features/reports/domain/entities/report.dart';
import 'package:buildflow/features/reports/presentation/providers/report_provider.dart';
import 'package:buildflow/features/reports/presentation/screens/report_detail_screen.dart';
import 'package:buildflow/features/reports/presentation/screens/report_list_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_app.dart';

const _owner = User(
  id: 'user-owner-1',
  email: 'owner@buildflow.kg',
  name: 'Асан Бекович',
  role: UserRole.owner,
  companyId: 'company-1',
);

class _Reports extends FakeReportRepository {
  _Reports(this.reports);

  final List<Report> reports;

  @override
  Future<Result<List<Report>>> getReports() async => Success(reports);
}

/// A report from the server: its time in UTC, whatever the phone's zone.
Report _report(String id, DateTime at) => Report(
      id: id,
      projectId: 'project-1',
      projectName: 'ЖК «Ала-Тоо Резиденс»',
      authorId: 'user-foreman-1',
      authorName: 'Бакыт Касымов',
      text: 'Отчёт $id',
      photos: const [],
      createdAt: at,
    );

/// The moment [hour]:[minute] today on the phone's clock, [offset] from UTC.
DateTime _today(Duration offset, int hour, int minute) {
  final clock = DateFormatter.local(DateTime.now());
  return DateTime.utc(clock.year, clock.month, clock.day, hour, minute)
      .subtract(offset);
}

void main() {
  final l10n = AppLocalizationsRu();

  tearDown(() => DateFormatter.debugUtcOffset = null);

  Future<void> show(
    WidgetTester tester,
    Widget screen,
    List<Report> reports,
  ) async {
    await pumpTestApp(
      tester,
      screen,
      overrides: [
        currentUserProvider.overrideWithValue(_owner),
        reportRepositoryProvider.overrideWithValue(_Reports(reports)),
      ],
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  for (final (name, offset) in const [
    ('+6', Duration(hours: 6)),
    ('-5', Duration(hours: -5)),
  ]) {
    group('at $name', () {
      setUp(() => DateFormatter.debugUtcOffset = offset);

      testWidgets('the report list shows local times under local days',
          (tester) async {
        await show(tester, const ReportListScreen(), [
          _report('r1', _today(offset, 11, 47)),
          _report('r2', _today(offset, 5, 59)),
          // A minute before midnight it was still yesterday on the phone.
          _report(
            'r3',
            _today(offset, 0, 0).subtract(const Duration(minutes: 1)),
          ),
        ]);

        expect(find.text(l10n.today), findsOneWidget);
        expect(find.text(l10n.yesterday), findsOneWidget);
        expect(find.textContaining('11:47'), findsOneWidget);
        expect(find.textContaining('05:59'), findsOneWidget);
        expect(find.textContaining('23:59'), findsOneWidget);
      });

      testWidgets('the report page shows the local time', (tester) async {
        await show(tester, const ReportDetailScreen(reportId: 'r1'), [
          _report('r1', _today(offset, 11, 47)),
        ]);

        expect(find.textContaining('${l10n.today}, 11:47'), findsOneWidget);
      });

      testWidgets("the project card shows the local time of today's report",
          (tester) async {
        await show(tester, const ProjectListScreen(), [
          _report('r1', _today(offset, 11, 47)),
        ]);

        expect(find.text(l10n.reportAt('11:47')), findsOneWidget);
      });
    });
  }
}
