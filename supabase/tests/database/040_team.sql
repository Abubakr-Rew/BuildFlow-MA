-- Team: invite codes, joining by code, rate limits, member search, removal.
begin;
select plan(43);

select tests.new_owner('owner@a.kg', 'Асан Бекович', 'А') as owner \gset
select tests.company_of(:'owner') as company \gset
select tests.new_member(:'company', 'foreman', 'f1@a.kg', 'Бакыт Касымов') as f1 \gset
select tests.new_member(:'company', 'foreman', 'f2@a.kg', 'Данияр Жумабеков') as f2 \gset
select tests.new_member(:'company', 'worker', 'w1@a.kg', 'Эрлан Токтосунов') as w1 \gset
select tests.new_member(:'company', 'worker', 'w2@a.kg', 'Азамат Асанов') as w2 \gset
select tests.new_owner('owner@b.kg', 'Асан Чужой', 'Б') as owner_b \gset

-- ── Invites ──────────────────────────────────────────────────

select tests.login_as(:'owner');
select public.create_invite('worker') as invite \gset
select :'invite'::jsonb ->> 'code' as code \gset

select ok(:'code' ~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$', 'the code is 6 characters without look-alikes');
select is(
  :'invite'::jsonb - 'code' - 'createdAt' - 'expiresAt',
  jsonb_build_object('companyId', :'company', 'role', 'worker', 'isUsed', false),
  'create_invite returns the invite in the client format'
);
select is(
  ((:'invite'::jsonb ->> 'expiresAt')::timestamptz - (:'invite'::jsonb ->> 'createdAt')::timestamptz),
  interval '7 days',
  'the code lives 7 days'
);
select is(tests.error_of($$ select public.create_invite('owner') $$), 'PT400 invalid_role', 'no invites for owners');
select is(tests.error_of($$ select public.create_invite('boss') $$), 'PT400 invalid_role', 'an unknown role is rejected');

select tests.login_as(:'f1');
select is(tests.error_of($$ select public.create_invite('worker') $$), 'PT403 owner_only', 'a foreman cannot create invites');
select is((select count(*)::int from public.invites), 0, 'a foreman sees no invites');

select tests.login_as(:'owner');
select is((select count(*)::int from public.invites), 1, 'the owner sees the company invites');
select tests.login_as(:'owner_b');
select is((select count(*)::int from public.invites), 0, 'another company sees none');
reset role;

-- ── Joining ──────────────────────────────────────────────────

-- The code arrives as typed: lower case, with a dash and spaces.
select tests.create_user('new@a.kg',
  jsonb_build_object('name', 'Новый', 'role', 'owner', 'company_id', tests.company_of(:'owner_b'),
                     'company_name', 'Своя'),
  jsonb_build_object('invite_code', ' ' || lower(left(:'code', 3)) || '-' || right(:'code', 3) || ' ')
) as joined \gset

select results_eq(
  format($$ select role::text, company_id from public.profiles where id = %L $$, :'joined'),
  format($$ values ('worker', %L::uuid) $$, :'company'),
  'joining with a worker code and role=owner, company_id, company_name in metadata makes a worker of the inviting company'
);
select is((select count(*)::int from public.companies where name = 'Своя'), 0, 'no company is created for a joining member');
select results_eq(
  format($$ select used_at is not null, used_by from public.invites where code = %L $$, :'code'),
  format($$ values (true, %L::uuid) $$, :'joined'),
  'the code is spent by the new user'
);

select is(
  tests.error_of(format($$ select tests.create_user('again@a.kg', '{"name": "Ещё"}', %L) $$,
    jsonb_build_object('invite_code', :'code'))),
  'PT404 invalid_invite_code',
  'a used code is rejected'
);
select is(
  tests.error_of($$ select tests.create_user('unknown@a.kg', '{"name": "Ещё"}', '{"invite_code": "ZZZZZZ"}') $$),
  'PT404 invalid_invite_code',
  'an unknown code is rejected'
);

insert into public.invites (code, company_id, role, created_by, created_at, expires_at)
values ('EXP234', :'company', 'worker', :'owner', now() - interval '8 days', now() - interval '1 day');
select is(
  tests.error_of($$ select tests.create_user('late@a.kg', '{"name": "Поздний"}', '{"invite_code": "EXP234"}') $$),
  'PT404 invalid_invite_code',
  'an expired code is rejected'
);
select is((select count(*)::int from auth.users where email in ('again@a.kg', 'unknown@a.kg', 'late@a.kg')), 0,
  'a rejected code leaves no user');

insert into public.invites (code, company_id, role, created_by)
values ('FRM234', :'company', 'foreman', :'owner');
select is(
  tests.error_of($$ select tests.create_user('noname@a.kg', '{}', '{"invite_code": "FRM234"}') $$),
  'PT400 name_required',
  'a sign-up failing for another reason…'
);
select is((select used_at from public.invites where code = 'FRM234'), null, '…leaves the code unspent');
select tests.create_user('foreman3@a.kg', '{"name": "Прораб"}', '{"invite_code": "frm234"}') as foreman3 \gset
select is(
  (select role::text from public.profiles where id = :'foreman3'),
  'foreman',
  'a foreman code makes a foreman'
);

select tests.as_service();
insert into public.invites (code, company_id, role, created_by) values ('NEW234', :'company', 'worker', :'owner');
select ok(public.invite_is_redeemable('new-234'), 'invite_is_redeemable: a fresh code, normalized');
select ok(not public.invite_is_redeemable('FRM234'), 'invite_is_redeemable: a used code');
select ok(not public.invite_is_redeemable('EXP234'), 'invite_is_redeemable: an expired code');

-- ── Rate limit of joining ────────────────────────────────────

select is(
  (select array_agg(public.join_rate_limit('10.0.0.1', null)) from generate_series(1, 11)),
  array[true, true, true, true, true, true, true, true, true, true, false],
  '10 attempts a minute from one IP, the 11th is refused'
);
select ok(public.join_rate_limit('10.0.0.2', null), 'another IP is not affected');
select is(
  (select array_agg(public.join_rate_limit('10.1.0.' || i, 'device-1')) from generate_series(1, 11) i),
  array[true, true, true, true, true, true, true, true, true, true, false],
  '10 attempts a minute from one device, whatever the IP'
);
reset role;
insert into private.rate_limit_hits (key, hit_at)
select 'join:ip:10.0.0.3', now() - interval '61 seconds' from generate_series(1, 10);
select tests.as_service();
select ok(public.join_rate_limit('10.0.0.3', null), 'attempts older than a minute do not count');

select tests.login_as(:'owner');
select is(tests.error_of($$ select public.join_rate_limit('1.1.1.1', null) $$), '42501', 'app users cannot touch the limits');
reset role;

-- ── Search ───────────────────────────────────────────────────

create temp table cases (name text, query text, matches boolean) on commit drop;
insert into cases values
  ('Бакыт Касымов', 'БАКЫТ', true), ('Бакыт Касымов', 'бАкЫт', true),
  ('Бакыт Асанов', 'асан', true), ('Асан Бекович', 'асан', true),
  ('Айгуль Абдыраева-Асанова', 'асан', true),
  ('Бакыт Асанов', 'сан', false), ('Бакыт Касымов', 'ымов', false),
  ('Пётр Семёнов', 'семен', true), ('Петр Семенов', 'сёмен', true),
  ('Үмүт Өмүрбеков', 'үмүт', true), ('Үмүт Өмүрбеков', 'умут', true),
  ('Үмүт Өмүрбеков', 'өмүр', true), ('Үмүт Өмүрбеков', 'омур', true),
  ('Мөңкө Таңатаров', 'таңа', true), ('Мөңкө Таңатаров', 'тана', true),
  ('Бакыт Касымов', 'bakyt', true), ('Бакыт Касымов', 'Kasymov', true),
  ('Данияр Жумабеков', 'daniyar', true), ('Данияр Жумабеков', 'zhumabekov', true),
  ('Данияр Жумабеков', 'jumabekov', true), ('Эрлан Токтосунов', 'erlan', true),
  ('Айбек Чынгызов', 'aibek', true), ('Айбек Чынгызов', 'aybek', true),
  ('Айбек Чынгызов', 'chyngyz', true), ('Үмүт Өмүрбеков', 'ömür', true),
  ('Бакыт Касымов', 'бак кас', true), ('Бакыт Касымов', 'кас бак', true),
  ('Бакыт Касымов', 'бак асан', false),
  ('Бакыт Касымов', 'нурлан', false), ('Бакыт Касымов', 'zzz', false);

select is_empty(
  $$ select name, query, matches from cases where private.name_matches(name, query) <> matches $$,
  'name_matches follows matchName() of the client (member_search_test.dart)'
);

select tests.login_as(:'f1');
select is(
  (select jsonb_agg(m ->> 'name') from jsonb_array_elements(public.get_members('асан')) m),
  '["Азамат Асанов", "Асан Бекович"]'::jsonb,
  'get_members finds by the start of any word, sorted by name, own company only'
);
select is(
  (select jsonb_agg(m ->> 'name') from jsonb_array_elements(public.get_members(p_role => 'foreman')) m),
  '["Бакыт Касымов", "Данияр Жумабеков", "Прораб"]'::jsonb,
  'a role without a query lists that role'
);
select is(
  (select jsonb_agg(m ->> 'name') from jsonb_array_elements(public.get_members('асан', 'worker')) m),
  '["Азамат Асанов"]'::jsonb,
  'a role narrows the search'
);
select is(public.get_members(' а '), '[]'::jsonb, 'a query shorter than 2 characters finds nobody');
select is(jsonb_array_length(public.get_members()), 7, 'without arguments: the whole team');
select is(tests.error_of($$ select public.get_members(p_role => 'boss') $$), 'PT400 invalid_role', 'an unknown role is rejected');

-- assignedProjectIds: only what the caller sees.
reset role;
select tests.login_as(:'owner');
select public.create_project('Общий') ->> 'id' as shared \gset
select public.create_project('Чужой') ->> 'id' as hidden \gset
select public.update_project(:'shared', p_foreman_ids => array[:'f1'::uuid], p_worker_ids => array[:'w1'::uuid]) is not null as ok \gset
select public.update_project(:'hidden', p_worker_ids => array[:'w1'::uuid]) is not null as ok \gset
select is(
  (select tests.sorted(m -> 'assignedProjectIds') from jsonb_array_elements(public.get_members('эрлан')) m),
  tests.sorted(jsonb_build_array(:'shared', :'hidden')),
  'the owner sees all projects of a member'
);
select tests.login_as(:'f1');
select is(
  (select m -> 'assignedProjectIds' from jsonb_array_elements(public.get_members('эрлан')) m),
  jsonb_build_array(:'shared'),
  'a foreman sees only the shared ones'
);

-- ── Removal ──────────────────────────────────────────────────

select tests.as_service();
select is(public.remove_member(:'owner', :'w1'), 'removed', 'remove_member removes a member');
reset role;
select is(
  (select removed_at is not null from public.profiles where id = :'w1')
    and not exists (select 1 from public.project_members where user_id = :'w1'),
  true,
  'the member is marked removed and taken off every project'
);
select tests.as_service();
select is(public.remove_member(:'owner', :'w1'), 'already_removed', 'a second call says already_removed');
select is(tests.error_of(format($$ select public.remove_member(%L, %L) $$, :'owner', :'owner_b')),
  'PT404 not_found', 'a member of another company is not found');
select is(tests.error_of(format($$ select public.remove_member(%L, %L) $$, :'f1', :'w2')),
  'PT403 owner_only', 'only an owner removes members');
select is(tests.error_of(format($$ select public.remove_member(%L, %L) $$, :'owner', :'owner')),
  'PT400 cannot_remove_self', 'an owner cannot remove themselves');

select tests.login_as(:'f1');
select is(jsonb_array_length(public.get_members()), 6, 'a removed member is no longer listed');

select * from finish();
rollback;
