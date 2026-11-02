import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/features/projects/data/supabase_project_repository.dart';
import 'package:buildflow/features/projects/domain/entities/project_changes.dart';
import 'package:buildflow/features/projects/domain/entities/project_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_supabase.dart';

const _projectJson = {
  'id': 'b0000000-0000-4000-8000-000000000001',
  'name': 'ЖК «Ала-Тоо Резиденс»',
  'address': 'ул. Токтогула 125',
  'status': 'active',
  'companyId': 'c1',
  'foremanIds': ['f1'],
  'workerIds': ['w1', 'w2'],
  'progress': 65,
};

void main() {
  late FakeSupabase supabase;
  late SupabaseProjectRepository repo;

  setUp(() async {
    supabase = FakeSupabase();
    await supabase.signIn('owner');
    repo = SupabaseProjectRepository(gateway: supabase.gateway);
  });
  tearDown(() => supabase.dispose());

  test('get_projects is a list of projects', () async {
    supabase.rpc('get_projects', [_projectJson]);

    final projects = (await repo.getProjects()).value;

    expect(projects.single.name, 'ЖК «Ала-Тоо Резиденс»');
    expect(projects.single.workerIds, ['w1', 'w2']);
    expect(projects.single.progress, 65);
  });

  test('an update sends only what changed', () async {
    supabase.rpc('update_project', {..._projectJson, 'status': 'paused'});

    final project = (await repo.updateProject(
      _projectJson['id']! as String,
      const ProjectChanges(status: ProjectStatus.paused),
    ))
        .value;

    expect(project.status, ProjectStatus.paused);
    expect(supabase.rpcCalls('update_project').single, {
      'p_id': _projectJson['id'],
      'p_status': 'paused',
    });
  });

  test('a team change sends both lists', () async {
    supabase.rpc('update_project', _projectJson);

    await repo.updateProject(
      'p1',
      const ProjectChanges(foremanIds: ['f1'], workerIds: []),
    );

    expect(supabase.rpcCalls('update_project').single, {
      'p_id': 'p1',
      'p_foreman_ids': ['f1'],
      'p_worker_ids': <String>[],
    });
  });

  test('create_project trims the fields', () async {
    supabase.rpc('create_project', _projectJson);

    await repo.createProject(name: ' Новый ', address: ' ул. 1 ');

    expect(supabase.rpcCalls('create_project').single, {
      'p_name': 'Новый',
      'p_address': 'ул. 1',
    });
  });

  test('server errors keep their meaning', () async {
    supabase
      ..rpcFails('create_project', 403, 'owner_only')
      ..rpcFails('get_project', 404, 'not_found')
      ..rpcFails('update_project', 400, 'invalid_progress');

    expect(
      (await repo.createProject(name: 'x', address: '')).failure.code,
      FailureCode.forbidden,
    );
    expect((await repo.getProject('p1')).failure.code, FailureCode.notFound);
    expect(
      (await repo.updateProject('p1', const ProjectChanges(progress: 101)))
          .failure
          .code,
      FailureCode.validation,
    );
  });
}
