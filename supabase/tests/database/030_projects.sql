-- Projects: visibility by role, owner-only writes, partial update, teams.
begin;
select plan(28);

select tests.new_owner('owner@a.kg', 'Асан', 'А') as owner \gset
select tests.company_of(:'owner') as company \gset
select tests.new_member(:'company', 'foreman', 'f1@a.kg', 'Бакыт') as f1 \gset
select tests.new_member(:'company', 'foreman', 'f2@a.kg', 'Данияр') as f2 \gset
select tests.new_member(:'company', 'worker', 'w1@a.kg', 'Эрлан') as w1 \gset
select tests.new_member(:'company', 'worker', 'w2@a.kg', 'Азамат') as w2 \gset
select tests.new_member(:'company', 'worker', 'gone@a.kg', 'Ушедший') as gone \gset
update public.profiles set removed_at = now() where id = :'gone';

select tests.new_owner('owner@b.kg', 'Чужой', 'Б') as owner_b \gset
select tests.new_member(tests.company_of(:'owner_b'), 'foreman', 'f@b.kg', 'Чужой прораб') as foreman_b \gset

-- ── Create ───────────────────────────────────────────────────

select tests.login_as(:'owner');
select public.create_project('  ЖК «Ала-Тоо»  ', 'ул. Токтогула 125') ->> 'id' as p1 \gset
select public.create_project('Горный') ->> 'id' as p2 \gset

select is(
  public.get_project(:'p1'),
  jsonb_build_object('id', :'p1', 'name', 'ЖК «Ала-Тоо»', 'address', 'ул. Токтогула 125',
    'status', 'active', 'companyId', :'company', 'foremanIds', '[]'::jsonb,
    'workerIds', '[]'::jsonb, 'progress', 0),
  'create_project returns the project in the client format, name trimmed'
);

select is(tests.error_of($$ select public.create_project('   ') $$), 'PT400 invalid_name', 'a blank name is rejected');
select is(tests.error_of($$ select public.create_project(repeat('я', 201)) $$), 'PT400 invalid_name', 'a name over 200 is rejected');

select tests.login_as(:'f1');
select is(tests.error_of($$ select public.create_project('Свой') $$), 'PT403 owner_only', 'a foreman cannot create projects');
select tests.login_as(:'w1');
select is(tests.error_of($$ select public.create_project('Свой') $$), 'PT403 owner_only', 'a worker cannot create projects');

-- ── Update ───────────────────────────────────────────────────

select tests.login_as(:'owner');
select public.update_project(:'p1', p_foreman_ids => array[:'f1'::uuid],
  p_worker_ids => array[:'w1'::uuid, :'w2'::uuid]) as updated \gset
select is(
  tests.sorted(:'updated'::jsonb -> 'workerIds') || (:'updated'::jsonb -> 'foremanIds'),
  tests.sorted(jsonb_build_array(:'w1', :'w2')) || jsonb_build_array(:'f1'),
  'update_project sets the foremen and the workers'
);

select is(
  public.update_project(:'p1', p_status => 'paused') - 'workerIds',
  jsonb_build_object('id', :'p1', 'name', 'ЖК «Ала-Тоо»', 'address', 'ул. Токтогула 125',
    'status', 'paused', 'companyId', :'company', 'foremanIds', jsonb_build_array(:'f1'),
    'progress', 0),
  'a status change keeps the other fields'
);
select is(
  tests.sorted(public.get_project(:'p1') -> 'workerIds'),
  tests.sorted(jsonb_build_array(:'w1', :'w2')),
  'and the team'
);

select is(public.update_project(:'p1', p_progress => 70) ->> 'progress', '70', 'progress is updated');
select is(public.update_project(:'p1', p_worker_ids => array[:'w2'::uuid]) -> 'workerIds',
  jsonb_build_array(:'w2'), 'a new worker list replaces the old one');
select is(public.update_project(:'p1', p_worker_ids => array[]::uuid[]) -> 'workerIds',
  '[]'::jsonb, 'an empty list clears it');
select is(public.get_project(:'p1') -> 'foremanIds', jsonb_build_array(:'f1'),
  'changing workers keeps the foremen');

select is(tests.error_of(format($$ select public.update_project(%L, p_progress => 101) $$, :'p1')),
  'PT400 invalid_progress', 'progress over 100 is rejected');
select is(tests.error_of(format($$ select public.update_project(%L, p_progress => -5) $$, :'p1')),
  'PT400 invalid_progress', 'negative progress is rejected');
select is(tests.error_of(format($$ select public.update_project(%L, p_status => 'done') $$, :'p1')),
  'PT400 invalid_status', 'an unknown status is rejected');
select is(tests.error_of(format($$ select public.update_project(%L, p_foreman_ids => array[%L::uuid]) $$, :'p1', :'w1')),
  'PT400 invalid_member', 'a worker cannot be put in the foreman list');
select is(tests.error_of(format($$ select public.update_project(%L, p_foreman_ids => array[%L::uuid]) $$, :'p1', :'foreman_b')),
  'PT400 invalid_member', 'a foreman of another company cannot be put on the project');
select is(tests.error_of(format($$ select public.update_project(%L, p_worker_ids => array[%L::uuid]) $$, :'p1', :'gone')),
  'PT400 invalid_member', 'a removed member cannot be put on the project');

select tests.login_as(:'owner_b');
select is(tests.error_of(format($$ select public.update_project(%L, p_name => 'Моё') $$, :'p1')),
  'PT404 not_found', 'an owner of another company gets 404');
select tests.login_as(:'f1');
select is(tests.error_of(format($$ select public.update_project(%L, p_progress => 100) $$, :'p1')),
  'PT403 owner_only', 'a foreman cannot update the project');

-- ── Foremen ──────────────────────────────────────────────────

select tests.login_as(:'owner');
select is(public.assign_foreman(:'p2', :'f2') -> 'foremanIds', jsonb_build_array(:'f2'), 'assign_foreman adds a foreman');
select is(public.assign_foreman(:'p2', :'f2') -> 'foremanIds', jsonb_build_array(:'f2'), 'assigning twice changes nothing');
select is(public.remove_foreman(:'p2', :'f2') -> 'foremanIds', '[]'::jsonb, 'remove_foreman removes them');

-- ── Visibility ───────────────────────────────────────────────

select tests.login_as(:'owner');
select is(jsonb_array_length(public.get_projects()), 2, 'the owner sees every project of the company');

select tests.login_as(:'f1');
select is(
  (select jsonb_agg(p ->> 'id') from jsonb_array_elements(public.get_projects()) p),
  jsonb_build_array(:'p1'),
  'a foreman sees only the projects they are on'
);
select is(tests.error_of(format($$ select public.get_project(%L) $$, :'p2')),
  'PT404 not_found', 'another project is missing for them');

select tests.login_as(:'f2');
select is(
  (select count(*)::int from public.projects) + (select count(*)::int from public.project_members),
  0,
  'a foreman without projects sees no projects and no teams'
);

select tests.login_as(:'owner_b');
select is(public.get_projects(), '[]'::jsonb, 'another company sees none of these projects');

select * from finish();
rollback;
