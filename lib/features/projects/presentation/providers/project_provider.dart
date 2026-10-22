import 'package:buildflow/features/projects/data/fake_project_repository.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/domain/repositories/project_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => FakeProjectRepository(),
);

final projectsProvider =
    AsyncNotifierProvider<ProjectsNotifier, List<Project>>(
  ProjectsNotifier.new,
);

class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() async {
    final repo = ref.watch(projectRepositoryProvider);
    final result = await repo.getProjects();
    return result.when(
      success: (projects) => projects,
      failure: (f) => throw Exception(f.message),
    );
  }

  Future<bool> createProject({
    required String name,
    required String address,
  }) async {
    final repo = ref.read(projectRepositoryProvider);
    final result = await repo.createProject(name: name, address: address);
    return result.when(
      success: (_) {
        ref.invalidateSelf();
        return true;
      },
      failure: (_) => false,
    );
  }

  Future<bool> updateProject(Project project) async {
    final repo = ref.read(projectRepositoryProvider);
    final result = await repo.updateProject(project);
    return result.when(
      success: (_) {
        ref.invalidateSelf();
        return true;
      },
      failure: (_) => false,
    );
  }
}
