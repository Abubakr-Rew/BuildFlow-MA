import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';

/// Project repository contract.
abstract class ProjectRepository {
  /// Get all projects for the current user's company.
  Future<Result<List<Project>>> getProjects();

  /// Get a single project by ID.
  Future<Result<Project>> getProject(String id);

  /// Create a new project (owner only).
  Future<Result<Project>> createProject({
    required String name,
    required String address,
  });

  /// Update an existing project (owner only).
  Future<Result<Project>> updateProject(Project project);

  /// Assign a foreman to a project.
  Future<Result<Project>> assignForeman({
    required String projectId,
    required String foremanId,
  });

  /// Remove a foreman from a project.
  Future<Result<Project>> removeForeman({
    required String projectId,
    required String foremanId,
  });
}
