import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/projects/data/fake_project_repository.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/domain/entities/project_status.dart';
import 'package:buildflow/features/projects/presentation/providers/project_provider.dart';
import 'package:buildflow/features/projects/presentation/screens/project_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/test_app.dart';

const _owner = User(
  id: 'user-owner-1',
  email: 'owner@buildflow.kg',
  name: 'Асан Бекович',
  role: UserRole.owner,
  companyId: 'company-1',
);

// Loads the seeded projects but refuses every change.
class _ReadOnlyProjects extends FakeProjectRepository {
  _ReadOnlyProjects(this.failure);

  final Failure failure;

  @override
  Future<Result<Project>> createProject({
    required String name,
    required String address,
  }) async =>
      Err(failure);

  @override
  Future<Result<Project>> updateProject(Project project) async => Err(failure);
}

void main() {
  final l10n = AppLocalizationsRu();

  group('ProjectsNotifier mutations', () {
    test('setStatus passes the repository failure through', () async {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(_owner),
          projectRepositoryProvider.overrideWithValue(
            _ReadOnlyProjects(const Failure(FailureCode.forbidden)),
          ),
        ],
      );
      addTearDown(container.dispose);

      final project = (await container.read(projectsProvider.future)).first;
      final result = await container
          .read(projectsProvider.notifier)
          .setStatus(project, ProjectStatus.paused);
      expect(result.failure.code, FailureCode.forbidden);
    });

    test('createProject returns the created project', () async {
      final container = ProviderContainer(
        overrides: [currentUserProvider.overrideWithValue(_owner)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(projectsProvider.notifier)
          .createProject(name: 'Склад', address: 'ул. Тестовая 1');
      expect(result.value.name, 'Склад');
      final projects = await container.read(projectsProvider.future);
      expect(projects.map((p) => p.id), contains(result.value.id));
    });
  });

  group('ProjectListScreen', () {
    testWidgets('a failed create shows the failure and keeps the sheet', (
      tester,
    ) async {
      await pumpTestApp(
        tester,
        const ProjectListScreen(),
        overrides: [
          currentUserProvider.overrideWithValue(_owner),
          projectRepositoryProvider.overrideWithValue(
            _ReadOnlyProjects(const Failure(FailureCode.server)),
          ),
        ],
      );
      await tester.pump(const Duration(seconds: 1)); // projects load

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Склад');
      await tester.enterText(fields.at(1), 'ул. Тестовая 1');
      await tester.tap(find.text(l10n.save));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(l10n.errorServer), findsOneWidget);
      expect(find.text(l10n.projectName), findsOneWidget); // sheet still open

      await tester.pump(const Duration(seconds: 5)); // let the snackbar go
    });
  });
}
