import 'dart:async';

import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/team/data/fake_team_repository.dart';
import 'package:buildflow/features/team/presentation/providers/team_provider.dart';
import 'package:buildflow/features/team/presentation/screens/team_list_screen.dart';
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

// Removals wait for [gate].
class _GatedTeam extends FakeTeamRepository {
  final gate = Completer<void>();

  @override
  Future<Result<void>> removeMember(String memberId) async {
    await gate.future;
    return super.removeMember(memberId);
  }
}

void main() {
  final l10n = AppLocalizationsRu();

  testWidgets('a member being removed shows progress instead of the menu',
      (tester) async {
    final team = _GatedTeam();
    await pumpTestApp(
      tester,
      const TeamListScreen(),
      overrides: [
        currentUserProvider.overrideWithValue(_owner),
        teamRepositoryProvider.overrideWithValue(team),
      ],
    );
    await tester.pump(const Duration(seconds: 1)); // members load

    Finder inCard(Finder matching) => find.descendant(
          of: find.widgetWithText(Card, 'Бакыт Касымов'),
          matching: matching,
        );

    await tester.tap(inCard(find.byType(PopupMenuButton<bool>)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.removeMember));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.delete));
    // Not pumpAndSettle: the progress indicator never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(inCard(find.byType(PopupMenuButton<bool>)), findsNothing);
    expect(inCard(find.byType(CircularProgressIndicator)), findsOneWidget);

    team.gate.complete();
    // Removal, project cleanup and reloads: each reload starts on a frame.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.text('Бакыт Касымов'), findsNothing);
    expect(find.text(l10n.memberRemoved), findsOneWidget);

    await tester.pump(const Duration(seconds: 5)); // let the snackbar go
  });
}
