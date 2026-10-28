import 'dart:async';

import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/projects/data/fake_project_repository.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/domain/entities/project_status.dart';
import 'package:buildflow/features/projects/presentation/providers/project_provider.dart';
import 'package:buildflow/features/projects/presentation/screens/project_detail_screen.dart';
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

// Counts updates; while [gate] is open they wait for it to complete.
class _GatedProjects extends FakeProjectRepository {
  Completer<void>? gate;
  int updates = 0;

  @override
  Future<Result<Project>> updateProject(Project project) async {
    updates++;
    await gate?.future;
    return super.updateProject(project);
  }
}

void main() {
  final l10n = AppLocalizationsRu();

  Future<_GatedProjects> pumpProject(WidgetTester tester) async {
    final projects = _GatedProjects();
    await pumpTestApp(
      tester,
      const ProjectDetailScreen(projectId: 'project-1'),
      overrides: [
        currentUserProvider.overrideWithValue(_owner),
        projectRepositoryProvider.overrideWithValue(projects),
      ],
    );
    await tester.pump(const Duration(seconds: 1)); // project, team, reports
    return projects;
  }

  testWidgets('status menu and team editor are locked during a status change',
      (tester) async {
    final projects = await pumpProject(tester);
    final gate = projects.gate = Completer<void>();

    bool menuEnabled() => tester
        .widget<PopupMenuButton<ProjectStatus>>(
          find.byType(PopupMenuButton<ProjectStatus>),
        )
        .enabled;
    bool teamEditable() => tester
        .widget<TextButton>(
          find.ancestor(
            of: find.text(l10n.editTeam),
            matching: find.byWidgetPredicate((w) => w is TextButton),
          ),
        )
        .enabled;

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(
        CheckedPopupMenuItem<ProjectStatus>,
        l10n.statusPaused,
      ),
    );
    await tester.pumpAndSettle(); // the update waits for the gate

    expect(projects.updates, 1);
    expect(menuEnabled(), isFalse);
    expect(teamEditable(), isFalse);

    gate.complete();
    await tester.pump(const Duration(seconds: 1));

    expect(menuEnabled(), isTrue);
    expect(teamEditable(), isTrue);
    expect(find.text(l10n.statusChanged), findsOneWidget);

    await tester.pump(const Duration(seconds: 5)); // let the snackbar go
  });

  testWidgets('a double tap on save updates the team once', (tester) async {
    final projects = await pumpProject(tester);

    await tester.tap(find.text(l10n.editTeam));
    await tester.pumpAndSettle();
    // No pump in between: both taps land before the button rebuilds.
    await tester.tap(find.text(l10n.save));
    await tester.tap(find.text(l10n.save));
    await tester.pump(const Duration(seconds: 1));

    expect(projects.updates, 1);
    expect(find.text(l10n.teamSaved), findsOneWidget);

    await tester.pump(const Duration(seconds: 5)); // let the snackbar go
  });
}
