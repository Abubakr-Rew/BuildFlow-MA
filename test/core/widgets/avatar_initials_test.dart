import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/widgets/avatar_initials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  ),
);

void main() {
  group('initialsOf', () {
    test('one word gives one letter', () {
      expect(initialsOf('Бакыт'), 'Б');
    });

    test('two words give two letters', () {
      expect(initialsOf('Бакыт Касымов'), 'БК');
    });

    test('takes the first two words, upper case, extra spaces ignored', () {
      expect(initialsOf('  азамат   новиков  уулу '), 'АН');
    });

    test('blank name gives nothing', () {
      expect(initialsOf('   '), '');
    });
  });

  group('AvatarInitials', () {
    testWidgets('shows one letter for a one-word name', (tester) async {
      await _pump(tester, const AvatarInitials(name: 'Бакыт'));
      expect(find.text('Б'), findsOneWidget);
    });

    testWidgets('shows two letters for a two-word name', (tester) async {
      await _pump(tester, const AvatarInitials(name: 'Бакыт Касымов'));
      expect(find.text('БК'), findsOneWidget);
    });

    testWidgets('color is stable for a name and comes from the theme', (
      tester,
    ) async {
      await _pump(tester, const AvatarInitials(name: 'Бакыт Касымов'));
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(AvatarInitials),
          matching: find.byType(Container),
        ),
      );
      final color = (box.decoration! as BoxDecoration).color;
      final expected = BuildFlowThemeExtension.light
          .avatarFor('Бакыт Касымов')
          .bg;
      expect(color, expected);
      expect(
        BuildFlowThemeExtension.light.avatars.map((a) => a.bg),
        contains(color),
      );
    });
  });

  group('AvatarStack', () {
    testWidgets('collapses names past max into +N', (tester) async {
      await _pump(
        tester,
        const AvatarStack(
          names: [
            'Анна Ли',
            'Бакыт Касымов',
            'Данияр Жумабеков',
            'Ерлан О',
            'Жамиля К',
          ],
          max: 3,
        ),
      );
      expect(find.text('АЛ'), findsOneWidget);
      expect(find.text('БК'), findsOneWidget);
      expect(find.text('+3'), findsOneWidget);
      expect(find.text('ДЖ'), findsNothing);
    });
  });
}
