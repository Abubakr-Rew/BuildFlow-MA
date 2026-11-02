import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/domain/repositories/project_repository.dart';

/// API project repository skeleton. Selected with `Backend.supabase` until replaced;
/// every call fails until the backend is available.
class ApiProjectRepository implements ProjectRepository {
  @override
  Future<Result<List<Project>>> getProjects() async {
    // TODO: Implement with Dio
    return const Err(
      Failure(FailureCode.server, message: 'API not implemented'),
    );
  }

  @override
  Future<Result<Project>> getProject(String id) async {
    return const Err(
      Failure(FailureCode.server, message: 'API not implemented'),
    );
  }

  @override
  Future<Result<Project>> createProject({
    required String name,
    required String address,
  }) async {
    return const Err(
      Failure(FailureCode.server, message: 'API not implemented'),
    );
  }

  @override
  Future<Result<Project>> updateProject(Project project) async {
    return const Err(
      Failure(FailureCode.server, message: 'API not implemented'),
    );
  }

  @override
  Future<Result<Project>> assignForeman({
    required String projectId,
    required String foremanId,
  }) async {
    return const Err(
      Failure(FailureCode.server, message: 'API not implemented'),
    );
  }

  @override
  Future<Result<Project>> removeForeman({
    required String projectId,
    required String foremanId,
  }) async {
    return const Err(
      Failure(FailureCode.server, message: 'API not implemented'),
    );
  }
}
