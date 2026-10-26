import 'package:buildflow/features/projects/domain/entities/project_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'project.freezed.dart';
part 'project.g.dart';

@freezed
abstract class Project with _$Project {
  const factory Project({
    required String id,
    required String name,
    required String address,
    required ProjectStatus status,
    required String companyId,
    @Default([]) List<String> foremanIds,
    @Default([]) List<String> workerIds,
  }) = _Project;

  factory Project.fromJson(Map<String, dynamic> json) =>
      _$ProjectFromJson(json);
}
