import 'dart:math';

import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/domain/entities/project_status.dart';
import 'package:buildflow/features/projects/domain/repositories/project_repository.dart';

/// In-memory fake project repository with seeded demo data.
class FakeProjectRepository implements ProjectRepository {
  FakeProjectRepository({
    this.companyId = 'company-1',
    this.onProjectChanged,
  });

  final String companyId;

  /// Called after a project is created or updated, the way the server
  /// updates the project chat: the provider passes
  /// `FakeChatStore.syncProject`.
  final void Function(Project project)? onProjectChanged;
  final _random = Random();

  late final List<Project> _projects = [...seed];

  /// The demo projects. FakeChatStore starts the project chats from them.
  static const seed = <Project>[
    Project(
      id: 'project-1',
      name: 'ЖК «Ала-Тоо Резиденс»',
      address: 'ул. Токтогула 125, Бишкек',
      status: ProjectStatus.active,
      companyId: 'company-1',
      foremanIds: ['user-foreman-1'],
      workerIds: ['user-worker-1'],
      progress: 65,
    ),
    Project(
      id: 'project-2',
      name: 'Коттеджный посёлок «Горный»',
      address: 'с. Кок-Жар, Чуйская обл.',
      status: ProjectStatus.active,
      companyId: 'company-1',
      foremanIds: ['user-foreman-1', 'user-foreman-2'],
      workerIds: ['user-worker-1', 'user-worker-2'],
      progress: 30,
    ),
    Project(
      id: 'project-3',
      name: 'Офис «Байтик»',
      address: 'пр. Чуй 55А, Бишкек',
      status: ProjectStatus.paused,
      companyId: 'company-1',
      foremanIds: ['user-foreman-2'],
      workerIds: ['user-worker-2', 'user-worker-3'],
      progress: 45,
    ),
    Project(
      id: 'project-4',
      name: 'Склад на Дэн Сяопина',
      address: 'ул. Дэн Сяопина 200, Бишкек',
      status: ProjectStatus.finished,
      companyId: 'company-1',
      progress: 100,
    ),
  ];

  Future<void> _simulateLatency() async {
    final ms = 200 + _random.nextInt(400);
    await Future<void>.delayed(Duration(milliseconds: ms));
  }

  static Failure _notFound(String projectId) =>
      Failure(FailureCode.notFound, message: 'Project $projectId not found');

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
      return Err(_notFound(id));
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
    return Success(_changed(project));
  }

  @override
  Future<Result<Project>> updateProject(Project project) async {
    await _simulateLatency();
    final index = _projects.indexWhere((p) => p.id == project.id);
    if (index == -1) {
      return Err(_notFound(project.id));
    }
    _projects[index] = project;
    return Success(_changed(project));
  }

  @override
  Future<Result<Project>> assignForeman({
    required String projectId,
    required String foremanId,
  }) async {
    await _simulateLatency();
    final index = _projects.indexWhere((p) => p.id == projectId);
    if (index == -1) {
      return Err(_notFound(projectId));
    }
    final project = _projects[index];
    if (project.foremanIds.contains(foremanId)) {
      return Success(project);
    }
    final updated = project.copyWith(
      foremanIds: [...project.foremanIds, foremanId],
    );
    _projects[index] = updated;
    return Success(_changed(updated));
  }

  @override
  Future<Result<Project>> removeForeman({
    required String projectId,
    required String foremanId,
  }) async {
    await _simulateLatency();
    final index = _projects.indexWhere((p) => p.id == projectId);
    if (index == -1) {
      return Err(_notFound(projectId));
    }
    final project = _projects[index];
    final updated = project.copyWith(
      foremanIds: project.foremanIds.where((id) => id != foremanId).toList(),
    );
    _projects[index] = updated;
    return Success(_changed(updated));
  }

  Project _changed(Project project) {
    onProjectChanged?.call(project);
    return project;
  }
}
