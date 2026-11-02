-- Test helpers. Runs first (files run in name order) and stays in the local
-- database only: migrations never create the `tests` schema.
create extension if not exists pgtap with schema extensions;

create schema if not exists tests;
grant usage on schema tests to anon, authenticated;

-- An auth user, as GoTrue would insert it: the registration trigger fires.
create or replace function tests.create_user(
  p_email text,
  p_user_meta jsonb,
  p_app_meta jsonb default '{}'
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
    p_email, '', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb || p_app_meta,
    p_user_meta, now(), now()
  );
  return v_id;
end;
$$;

-- Owner of a new company.
create or replace function tests.new_owner(
  p_email text,
  p_name text default 'Директор',
  p_company text default 'Компания'
)
returns uuid
language sql
set search_path = ''
as $$
  select tests.create_user(p_email, jsonb_build_object('name', p_name, 'company_name', p_company))
$$;

-- A member of [p_company] with [p_role], bypassing invites: registers with a
-- throwaway company and moves the profile.
create or replace function tests.new_member(
  p_company uuid,
  p_role public.user_role,
  p_email text,
  p_name text default 'Сотрудник'
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_id uuid := tests.new_owner(p_email, p_name, 'tmp');
  v_tmp uuid := (select company_id from public.profiles where id = v_id);
begin
  update public.profiles set company_id = p_company, role = p_role where id = v_id;
  delete from public.companies where id = v_tmp;
  return v_id;
end;
$$;

create or replace function tests.company_of(p_user uuid)
returns uuid
language sql
stable
set search_path = ''
as $$
  select company_id from public.profiles where id = p_user
$$;

-- Acts as [p_user] until the next login_as / as_anon / `reset role`.
create or replace function tests.login_as(p_user uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', p_user, 'role', 'authenticated')::text, true);
end;
$$;

-- `authenticated` with no `sub`: auth.uid() is null.
create or replace function tests.as_authenticated_without_user()
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"role": "authenticated"}', true);
end;
$$;

create or replace function tests.as_anon()
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role": "anon"}', true);
end;
$$;

-- 'ok' if [p_sql] runs, otherwise 'SQLSTATE hint' for our own errors
-- ('PT403 account_removed') and just the SQLSTATE for the rest ('42501').
create or replace function tests.error_of(p_sql text)
returns text
language plpgsql
set search_path = ''
as $$
declare
  v_state text;
  v_hint text;
begin
  execute p_sql;
  return 'ok';
exception when others then
  get stacked diagnostics v_state = returned_sqlstate, v_hint = pg_exception_hint;
  if v_state not like 'PT%' then
    return v_state;
  end if;
  return v_state || coalesce(' ' || nullif(v_hint, ''), '');
end;
$$;

-- Client-callable functions of the public schema, from the catalog.
create or replace function tests.public_functions()
returns table (oid oid, name text, nargs int)
language sql
stable
set search_path = ''
as $$
  select p.oid, p.proname::text, p.pronargs::int
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and not exists (
      select 1 from pg_catalog.pg_depend d
      where d.objid = p.oid and d.deptype = 'e'
    )
$$;

-- `select * from public.<name>(null, …)` with [p_nargs] nulls.
create or replace function tests.call_with_nulls(p_name text, p_nargs int)
returns text
language sql
immutable
set search_path = ''
as $$
  select format('select * from public.%I(%s)', p_name,
    coalesce((select string_agg('null', ', ') from generate_series(1, p_nargs)), ''))
$$;

grant execute on all functions in schema tests to anon, authenticated;

select plan(1);
select pass('test helpers installed');
select * from finish();
