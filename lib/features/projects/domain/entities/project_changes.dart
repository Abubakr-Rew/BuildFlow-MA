import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/domain/entities/project_status.dart';
import 'package:flutter/foundation.dart';

/// The fields of a project update; `null` means «unchanged». Only what
/// changed goes to the server, so a status change on one phone and a team
/// change on another don't overwrite each other (`update_project`).
@immutable
class ProjectChanges {
  const ProjectChanges({
    this.name,
    this.address,
    this.status,
    this.progress,
    this.foremanIds,
    this.workerIds,
  });

  final String? name;
  final String? address;
  final ProjectStatus? status;

  /// Readiness, 0–100.
  final int? progress;
  final List<String>? foremanIds;
  final List<String>? workerIds;

  /// [project] with these changes.
  Project applyTo(Project project) => project.copyWith(
        name: name ?? project.name,
        address: address ?? project.address,
        status: status ?? project.status,
        progress: progress ?? project.progress,
        foremanIds: foremanIds ?? project.foremanIds,
        workerIds: workerIds ?? project.workerIds,
      );

  @override
  bool operator ==(Object other) =>
      other is ProjectChanges &&
      other.name == name &&
      other.address == address &&
      other.status == status &&
      other.progress == progress &&
      listEquals(other.foremanIds, foremanIds) &&
      listEquals(other.workerIds, workerIds);

  @override
  int get hashCode => Object.hash(
        name,
        address,
        status,
        progress,
        Object.hashAll(foremanIds ?? const []),
        Object.hashAll(workerIds ?? const []),
      );
}
