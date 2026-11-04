import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/supabase/json.dart';
import 'package:buildflow/core/supabase/supabase_gateway.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/domain/entities/project_changes.dart';
import 'package:buildflow/features/projects/domain/repositories/project_repository.dart';

/// [ProjectRepository] over the project RPCs (docs/supabase-plan.md). The
/// server shows a foreman or a worker only their projects and keeps each
/// project chat's team in line with the project.
class SupabaseProjectRepository implements ProjectRepository {
  SupabaseProjectRepository({required this.gateway});

  final SupabaseGateway gateway;

  @override
  Future<Result<List<Project>>> getProjects() =>
      gateway.rpc('get_projects', listOf(Project.fromJson));

  @override
  Future<Result<Project>> getProject(String id) =>
      gateway.rpc('get_project', one(Project.fromJson), params: {'p_id': id});

  @override
  Future<Result<Project>> createProject({
    required String name,
    required String address,
  }) =>
      gateway.rpc(
        'create_project',
        one(Project.fromJson),
        params: {'p_name': name.trim(), 'p_address': address.trim()},
      );

  @override
  Future<Result<Project>> updateProject(String id, ProjectChanges changes) =>
      gateway.rpc(
        'update_project',
        one(Project.fromJson),
        // Left out means «unchanged» on the server.
        params: {
          'p_id': id,
          if (changes.name case final name?) 'p_name': name.trim(),
          if (changes.address case final address?) 'p_address': address.trim(),
          if (changes.status case final status?) 'p_status': status.name,
          if (changes.progress case final progress?) 'p_progress': progress,
          if (changes.foremanIds case final ids?) 'p_foreman_ids': ids,
          if (changes.workerIds case final ids?) 'p_worker_ids': ids,
        },
      );

  @override
  Future<Result<Project>> assignForeman({
    required String projectId,
    required String foremanId,
  }) =>
      gateway.rpc(
        'assign_foreman',
        one(Project.fromJson),
        params: {'p_project_id': projectId, 'p_foreman_id': foremanId},
      );

  @override
  Future<Result<Project>> removeForeman({
    required String projectId,
    required String foremanId,
  }) =>
      gateway.rpc(
        'remove_foreman',
        one(Project.fromJson),
        params: {'p_project_id': projectId, 'p_foreman_id': foremanId},
      );
}
