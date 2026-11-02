-- Registration trigger, get_me, visibility of companies and profiles.
begin;
select plan(19);

-- ── Registration ─────────────────────────────────────────────

select tests.new_owner('Owner@Test.kg', 'Асан Бекович', 'СтройБишкек') as owner \gset

select results_eq(
  $$ select p.role::text, p.name, p.email, c.name
     from public.profiles p join public.companies c on c.id = p.company_id
     where p.id = $$ || quote_literal(:'owner') || $$::uuid $$,
  $$ values ('owner', 'Асан Бекович', 'owner@test.kg', 'СтройБишкек') $$,
  'sign-up with company_name creates the company and its owner, email in lower case'
);

-- Role and company never come from metadata.
select tests.new_owner('other@test.kg', 'Другой', 'Другая') as other \gset

select tests.create_user('sneaky@test.kg', jsonb_build_object(
  'name', 'Хитрый', 'company_name', 'Своя',
  'role', 'worker', 'company_id', tests.company_of(:'other'))) as sneaky \gset

select results_eq(
  $$ select p.role::text, p.company_id <> tests.company_of($$ || quote_literal(:'other') || $$)
     from public.profiles p where p.id = $$ || quote_literal(:'sneaky') || $$::uuid $$,
  $$ values ('owner', true) $$,
  'role and company_id in user metadata are ignored'
);

select tests.create_user('sneaky2@test.kg',
  jsonb_build_object('name', 'Хитрый', 'company_name', 'Своя'),
  jsonb_build_object('role', 'foreman', 'company_id', tests.company_of(:'other'))) as sneaky2 \gset

select results_eq(
  $$ select p.role::text, p.company_id <> tests.company_of($$ || quote_literal(:'other') || $$)
     from public.profiles p where p.id = $$ || quote_literal(:'sneaky2') || $$::uuid $$,
  $$ values ('owner', true) $$,
  'role and company_id in app metadata are ignored'
);

select is(
  tests.error_of($$ select tests.create_user('noname@test.kg', '{"company_name": "Х"}') $$),
  'PT400 name_required',
  'sign-up without a name is rejected'
);

select is(
  tests.error_of($$ select tests.create_user('blank@test.kg', '{"name": "  ", "company_name": "Х"}') $$),
  'PT400 name_required',
  'a blank name counts as none'
);

select is(
  tests.error_of($$ select tests.create_user('nocompany@test.kg', '{"name": "Имя"}') $$),
  'PT400 company_name_required',
  'sign-up with neither a company name nor an invite code is rejected'
);

-- Only the server sets app metadata; an invite code in user metadata means nothing.
select is(
  tests.error_of($$ select tests.create_user('selfinvite@test.kg', '{"name": "Имя", "invite_code": "ABC234"}') $$),
  'PT400 company_name_required',
  'an invite code in user metadata is ignored'
);

select is(
  (select count(*)::int from auth.users where email in ('noname@test.kg', 'nocompany@test.kg', 'selfinvite@test.kg')),
  0,
  'a rejected sign-up leaves no auth user'
);

update auth.users set email = 'New@Test.kg' where id = :'owner';
select is(
  (select email from public.profiles where id = :'owner'),
  'new@test.kg',
  'an email change reaches the profile'
);

-- ── get_me ───────────────────────────────────────────────────

select tests.login_as(:'owner');
select is(
  public.get_me(),
  jsonb_build_object(
    'user', jsonb_build_object('id', :'owner', 'email', 'new@test.kg', 'name', 'Асан Бекович',
                               'role', 'owner', 'companyId', tests.company_of(:'owner')),
    'company', jsonb_build_object('id', tests.company_of(:'owner'), 'name', 'СтройБишкек')),
  'get_me returns the user and the company'
);
reset role;

-- ── Visibility ───────────────────────────────────────────────

select tests.new_member(tests.company_of(:'owner'), 'foreman', 'foreman@test.kg', 'Бакыт') as foreman \gset
select tests.new_member(tests.company_of(:'owner'), 'worker', 'removed@test.kg', 'Ушедший') as removed \gset
update public.profiles set removed_at = now() where id = :'removed';

select tests.login_as(:'foreman');
select results_eq(
  $$ select name from public.companies $$,
  $$ values ('СтройБишкек') $$,
  'a member sees only the own company'
);
select set_eq(
  $$ select name from public.profiles $$,
  $$ values ('Асан Бекович'), ('Бакыт') $$,
  'a member sees active colleagues only: no other companies, no removed members'
);

select tests.login_as(:'removed');
select is(
  (select count(*)::int from public.companies) + (select count(*)::int from public.profiles),
  0,
  'a removed member sees nothing'
);
select is(
  tests.error_of('select public.get_me()'),
  'PT403 account_removed',
  'a removed member gets 403 account_removed'
);

-- A user who exists in auth but has no profile.
reset role;
select tests.new_owner('ghost@test.kg') as ghost \gset
delete from public.profiles where id = :'ghost';

select tests.login_as(:'ghost');
select is(
  (select count(*)::int from public.companies) + (select count(*)::int from public.profiles),
  0,
  'a user without a profile sees nothing'
);
select is(
  tests.error_of('select public.get_me()'),
  'PT403 no_profile',
  'a user without a profile gets 403 no_profile'
);

select tests.as_anon();
select is(
  tests.error_of('select count(*) from public.profiles'),
  '42501',
  'anon cannot read profiles'
);
select is(
  tests.error_of('select public.get_me()'),
  '42501',
  'anon cannot call get_me'
);

-- Writes go through functions only.
select tests.login_as(:'owner');
select is(
  tests.error_of($$ update public.profiles set role = 'owner' where id = '$$ || :'foreman' || $$' $$),
  '42501',
  'a user cannot write profiles directly'
);

select * from finish();
rollback;
