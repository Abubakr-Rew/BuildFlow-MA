import 'package:buildflow/features/projects/data/fake_project_repository.dart';
import 'package:buildflow/features/projects/domain/entities/project_status.dart';
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
      expect(result.isFailure, isTrue);
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

    test('updateProject modifies existing project', () async {
      final getResult = await repo.getProject('project-3');
      final project = getResult.value;
      final updated = project.copyWith(status: ProjectStatus.active);
      final result = await repo.updateProject(updated);
      expect(result.isSuccess, isTrue);
      expect(result.value.status, ProjectStatus.active);
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
}
