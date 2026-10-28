import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/widgets/status_badge.dart';
import 'package:buildflow/features/projects/domain/entities/project_status.dart';
import 'package:buildflow/features/projects/presentation/widgets/project_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsRu();

  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    final t = theme.extension<BuildFlowThemeExtension>()!;
    final expected = {
      ProjectStatus.active: (l10n.statusActive, t.active),
      ProjectStatus.paused: (l10n.statusPaused, t.paused),
      ProjectStatus.finished: (l10n.statusFinished, t.finished),
    };

    group('ProjectStatusBadge ($name)', () {
      test('covers every status', () {
        expect(expected.keys, containsAll(ProjectStatus.values));
      });

      for (final status in ProjectStatus.values) {
        testWidgets('${status.name}: label and theme colors', (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              locale: const Locale('ru'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: ProjectStatusBadge(status: status)),
            ),
          );
          final (label, tone) = expected[status]!;

          final text = tester.widget<Text>(find.text(label));
          expect(text.style?.color, tone.fg);

          final pill = tester.widget<Container>(
            find.descendant(
              of: find.byType(StatusBadge),
              matching: find.byType(Container),
            ),
          );
          expect((pill.decoration! as ShapeDecoration).color, tone.bg);
        });
      }
    });
  }

  test('"finished" reads «Сдан»', () {
    expect(l10n.statusFinished, 'Сдан');
  });
}
