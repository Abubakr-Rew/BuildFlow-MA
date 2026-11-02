import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/features/projects/data/fake_project_repository.dart';
import 'package:buildflow/features/projects/domain/entities/project_changes.dart';
import 'package:buildflow/features/projects/domain/entities/project_status.dart';
import 'package:buildflow/features/team/data/fake_team_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeProjectRepository repo;

  setUp(() {
    repo = FakeProjectRepository();
  });

  group('FakeProjectRepository', () {
    test('getProjects returns seeded data', () async {
      final result = await repo.getProjects();
      expect(result.isSuccess, isTrue);
      expect(result.value.length, 4);
    });

    test('getProject returns correct project', () async {
      final result = await repo.getProject('project-1');
      expect(result.isSuccess, isTrue);
      expect(result.value.name, contains('Ала-Тоо'));
    });

    test('getProject fails for unknown id', () async {
      final result = await repo.getProject('nonexistent');
      expect(result.failure.code, FailureCode.notFound);
    });

    test('changes to an unknown project fail with notFound', () async {
      final results = [
        await repo.updateProject(
          'nonexistent',
          const ProjectChanges(status: ProjectStatus.paused),
        ),
        await repo.assignForeman(projectId: 'nonexistent', foremanId: 'f'),
        await repo.removeForeman(projectId: 'nonexistent', foremanId: 'f'),
      ];
      for (final result in results) {
        expect(result.failure.code, FailureCode.notFound);
        expect(result.failure.message, contains('nonexistent'));
      }
    });

    test('createProject adds a new project', () async {
      final result = await repo.createProject(
        name: 'Новый объект',
        address: 'ул. Тестовая 1',
      );
      expect(result.isSuccess, isTrue);
      expect(result.value.name, 'Новый объект');
      expect(result.value.status, ProjectStatus.active);

      // Verify it appears in the list
      final all = await repo.getProjects();
      expect(all.value.length, 5);
    });

    test('updateProject changes only the given fields', () async {
      final before = (await repo.getProject('project-3')).value;
      final result = await repo.updateProject(
        'project-3',
        const ProjectChanges(status: ProjectStatus.active),
      );
      expect(result.isSuccess, isTrue);
      expect(result.value.status, ProjectStatus.active);
      expect(result.value.progress, before.progress);
      expect(result.value.foremanIds, before.foremanIds);
    });

    test('assignForeman adds foreman to project', () async {
      final result = await repo.assignForeman(
        projectId: 'project-4',
        foremanId: 'user-foreman-1',
      );
      expect(result.isSuccess, isTrue);
      expect(result.value.foremanIds, contains('user-foreman-1'));
    });

    test('removeForeman removes foreman from project', () async {
      final result = await repo.removeForeman(
        projectId: 'project-1',
        foremanId: 'user-foreman-1',
      );
      expect(result.isSuccess, isTrue);
      expect(result.value.foremanIds, isNot(contains('user-foreman-1')));
    });
  });

  test('a member removed from the company leaves every project', () async {
    final team = FakeTeamStore();
    final changed = <String>[];
    final repo = FakeProjectRepository(
      teamStore: team,
      onProjectChanged: (p) => changed.add(p.id),
    );
    final workerMember = team.memberByUserId('user-worker-2')!;

    team.removeMember(workerMember.id);

    final projects = (await repo.getProjects()).value;
    expect(
      projects.where((p) => p.workerIds.contains('user-worker-2')),
      isEmpty,
    );
    // Only the projects they were on changed (and so their chats).
    expect(changed, ['project-2', 'project-3']);
    repo.dispose();
  });
}
