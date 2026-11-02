import 'package:buildflow/core/config.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/chat/presentation/providers/fake_chat_store_provider.dart';
import 'package:buildflow/features/projects/data/api_project_repository.dart';
import 'package:buildflow/features/projects/data/fake_project_repository.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/domain/entities/project_status.dart';
import 'package:buildflow/features/projects/domain/repositories/project_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => kBackend == Backend.fake
      ? FakeProjectRepository(
          // The server keeps each project chat's team in line with the
          // project; the fake store needs to be told.
          onProjectChanged: ref.watch(fakeChatStoreProvider).syncProject,
        )
      : ApiProjectRepository(),
);

/// Whether [user] can see [project]: directors see everything,
/// foremen and workers only the projects they are assigned to.
bool canSeeProject(User user, Project project) => switch (user.role) {
      UserRole.owner => true,
      UserRole.foreman => project.foremanIds.contains(user.id),
      UserRole.worker => project.workerIds.contains(user.id),
    };

/// Projects visible to the current user.
final projectsProvider =
    AsyncNotifierProvider<ProjectsNotifier, List<Project>>(
  ProjectsNotifier.new,
);

/// A single visible project, or `null` if it doesn't exist / isn't visible.
final projectByIdProvider = Provider.family<AsyncValue<Project?>, String>(
  (ref, id) => ref.watch(projectsProvider).whenData(
        (list) => list.where((p) => p.id == id).firstOrNull,
      ),
);

class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];

    final repo = ref.watch(projectRepositoryProvider);
    final result = await repo.getProjects();
    return result.when(
      success: (projects) =>
          projects.where((p) => canSeeProject(user, p)).toList(),
      failure: (f) => throw f,
    );
  }

  Future<Result<Project>> createProject({
    required String name,
    required String address,
  }) async {
    final repo = ref.read(projectRepositoryProvider);
    final result = await repo.createProject(name: name, address: address);
    if (result.isSuccess) ref.invalidateSelf();
    return result;
  }

  Future<Result<Project>> updateProject(Project project) async {
    final repo = ref.read(projectRepositoryProvider);
    final result = await repo.updateProject(project);
    if (result.isSuccess) ref.invalidateSelf();
    return result;
  }

  Future<Result<Project>> setStatus(Project project, ProjectStatus status) =>
      updateProject(project.copyWith(status: status));

  /// [percent] is clamped to 0–100.
  Future<Result<Project>> setProgress(Project project, int percent) =>
      updateProject(project.copyWith(progress: percent.clamp(0, 100)));

  Future<Result<Project>> setTeam(
    Project project, {
    required List<String> foremanIds,
    required List<String> workerIds,
  }) =>
      updateProject(
        project.copyWith(foremanIds: foremanIds, workerIds: workerIds),
      );
}
