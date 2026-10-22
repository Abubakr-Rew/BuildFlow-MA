import 'dart:math';

import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/domain/entities/project_status.dart';
import 'package:buildflow/features/projects/domain/repositories/project_repository.dart';

/// In-memory fake project repository with seeded demo data.
class FakeProjectRepository implements ProjectRepository {
  FakeProjectRepository({this.companyId = 'company-1'});

  final String companyId;
  final _random = Random();

  final List<Project> _projects = [
    const Project(
      id: 'project-1',
      name: 'ЖК "Ала-Тоо Резиденс"',
      address: 'ул. Токтогула 125, Бишкек',
      status: ProjectStatus.active,
      companyId: 'company-1',
      foremanIds: ['user-foreman-1'],
    ),
    const Project(
      id: 'project-2',
      name: 'Коттеджный посёлок "Горный"',
      address: 'с. Кок-Жар, Чуйская обл.',
      status: ProjectStatus.active,
      companyId: 'company-1',
      foremanIds: ['user-foreman-1', 'user-foreman-2'],
    ),
    const Project(
      id: 'project-3',
      name: 'Офис "Байтик"',
      address: 'пр. Чуй 55А, Бишкек',
      status: ProjectStatus.paused,
      companyId: 'company-1',
      foremanIds: ['user-foreman-2'],
    ),
    const Project(
      id: 'project-4',
      name: 'Склад на Дэн Сяопина',
      address: 'ул. Дэн Сяопина 200, Бишкек',
      status: ProjectStatus.finished,
      companyId: 'company-1',
    ),
  ];

  Future<void> _simulateLatency() async {
    final ms = 200 + _random.nextInt(400);
    await Future<void>.delayed(Duration(milliseconds: ms));
  }

  @override
  Future<Result<List<Project>>> getProjects() async {
    await _simulateLatency();
    final filtered = _projects
        .where((p) => p.companyId == companyId)
        .toList();
    return Success(filtered);
  }

  @override
  Future<Result<Project>> getProject(String id) async {
    await _simulateLatency();
    final project = _projects.where((p) => p.id == id).firstOrNull;
    if (project == null) {
      return const Err(StorageFailure(message: 'Объект не найден'));
    }
    return Success(project);
  }

  @override
  Future<Result<Project>> createProject({
    required String name,
    required String address,
  }) async {
    await _simulateLatency();
    final project = Project(
      id: 'project-${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      address: address.trim(),
      status: ProjectStatus.active,
      companyId: companyId,
    );
    _projects.add(project);
    return Success(project);
  }

  @override
  Future<Result<Project>> updateProject(Project project) async {
    await _simulateLatency();
    final index = _projects.indexWhere((p) => p.id == project.id);
    if (index == -1) {
      return const Err(StorageFailure(message: 'Объект не найден'));
    }
    _projects[index] = project;
    return Success(project);
  }

  @override
  Future<Result<Project>> assignForeman({
    required String projectId,
    required String foremanId,
  }) async {
    await _simulateLatency();
    final index = _projects.indexWhere((p) => p.id == projectId);
    if (index == -1) {
      return const Err(StorageFailure(message: 'Объект не найден'));
    }
    final project = _projects[index];
    if (project.foremanIds.contains(foremanId)) {
      return Success(project);
    }
    final updated = project.copyWith(
      foremanIds: [...project.foremanIds, foremanId],
    );
    _projects[index] = updated;
    return Success(updated);
  }

  @override
  Future<Result<Project>> removeForeman({
    required String projectId,
    required String foremanId,
  }) async {
    await _simulateLatency();
    final index = _projects.indexWhere((p) => p.id == projectId);
    if (index == -1) {
      return const Err(StorageFailure(message: 'Объект не найден'));
    }
    final project = _projects[index];
    final updated = project.copyWith(
      foremanIds: project.foremanIds.where((id) => id != foremanId).toList(),
    );
    _projects[index] = updated;
    return Success(updated);
  }
}
