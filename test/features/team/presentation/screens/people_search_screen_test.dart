import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/widgets/bf_card.dart';
import 'package:buildflow/core/widgets/bf_chip.dart';
import 'package:buildflow/core/widgets/empty_state.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/team/presentation/screens/people_search_screen.dart';
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

void main() {
  final l10n = AppLocalizationsRu();

  Future<void> pumpSearch(WidgetTester tester) async {
    await pumpTestApp(
      tester,
      const PeopleSearchScreen(),
      overrides: [currentUserProvider.overrideWithValue(_foreman)],
    );
    // Members and projects load in parallel, each with fake latency.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(const Duration(milliseconds: 300)); // debounce
  }

  /// Text drawn on the match highlight.
  List<String> highlighted(WidgetTester tester) {
    final color = BuildFlowThemeExtension.light.matchHighlight;
    final out = <String>[];
    for (final text in tester.widgetList<RichText>(find.byType(RichText))) {
      text.text.visitChildren((span) {
        if (span is TextSpan &&
            span.text != null &&
            span.style?.backgroundColor == color) {
          out.add(span.text!);
        }
        return true;
      });
    }
    return out;
  }

  testWidgets('«асан» finds people by first name and surname, highlighted',
      (tester) async {
    await pumpSearch(tester);
    expect(find.text(l10n.searchPeopleStart), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'асан');
    await tester.pump(const Duration(milliseconds: 100));
    // Still debouncing: the results haven't changed yet.
    expect(find.text(l10n.searchPeopleStart), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Асан Бекович'), findsOneWidget);
    expect(find.text('Азамат Асанов'), findsOneWidget);
    expect(find.text('Бакыт Касымов'), findsNothing); // the user themself
    expect(find.text('Данияр Жумабеков'), findsNothing);
    expect(highlighted(tester), ['Асан', 'Асан']);
    expect(find.text(l10n.searchCompanyOnly), findsOneWidget);
  });

  testWidgets('a role chip narrows the results', (tester) async {
    await pumpSearch(tester);
    await type(tester, 'асан');
    expect(find.byType(BfCard), findsNWidgets(2));

    await tester.tap(find.widgetWithText(BfChip, l10n.roleWorker));
    await tester.pump();
    expect(find.byType(BfCard), findsOneWidget);
    expect(find.text('Азамат Асанов'), findsOneWidget);
    expect(find.text('Асан Бекович'), findsNothing);

    await tester.tap(find.widgetWithText(BfChip, l10n.filterAll));
    await tester.pump();
    expect(find.text('Асан Бекович'), findsOneWidget);
  });

  testWidgets('nobody found shows the empty state', (tester) async {
    await pumpSearch(tester);
    await type(tester, 'zzzz');

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text(l10n.nobodyFound), findsOneWidget);
    expect(find.text(l10n.nobodyFoundHint), findsOneWidget);
    expect(find.byType(BfCard), findsNothing);
  });

  testWidgets('an opened person shows in the sheet, then in recent',
      (tester) async {
    await pumpSearch(tester);
    await type(tester, 'azamat'); // Latin is read as Cyrillic

    await tester.tap(find.text('Азамат Асанов'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('worker3@buildflow.kg'), findsOneWidget);
    // Азамат works on «Байтик», which this foreman doesn't see.
    expect(find.text(l10n.noSharedProjects), findsOneWidget);

    await tester.tapAt(const Offset(20, 20)); // closes the sheet
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip(l10n.clearSearch));
    await tester.pump();

    expect(find.text(l10n.recentPeople), findsOneWidget);
    expect(find.text('Азамат Асанов'), findsOneWidget);
  });
}
