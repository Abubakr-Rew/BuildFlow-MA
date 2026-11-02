-- Who may call what and touch which table. Every function of the public
-- schema must be listed below: a new one fails these tests until it is.
begin;
select plan(13);

create temp table client_functions (name text primary key) on commit drop;
insert into client_functions values
  ('get_me'),
  ('get_projects'), ('get_project'), ('create_project'), ('update_project'),
  ('assign_foreman'), ('remove_foreman'),
  ('create_invite'), ('get_members'),
  ('create_upload'), ('get_reports'), ('get_report'), ('submit_report'),
  ('get_chats'), ('get_messages'), ('send_message'), ('get_or_create_direct'),
  ('mark_read'), ('mark_listened');

-- Called by Edge Functions with the service role key only.
create temp table service_functions (name text primary key) on commit drop;
insert into service_functions values
  ('invite_is_redeemable'), ('join_rate_limit'), ('remove_member');

grant select on client_functions, service_functions to anon, authenticated;

-- ── Catalog ──────────────────────────────────────────────────

select is_empty(
  $$ select name from tests.public_functions()
     where name not in (select name from client_functions)
       and name not in (select name from service_functions) $$,
  'every public function is listed as a client or a service function'
);

select is_empty(
  $$ select name from tests.public_functions()
     where has_function_privilege('anon', oid, 'execute') $$,
  'anon may execute no public function'
);

select is_empty(
  $$ select n.nspname || '.' || p.proname
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'private' and has_function_privilege('anon', p.oid, 'execute') $$,
  'anon may execute no private function'
);

select set_eq(
  $$ select name from tests.public_functions()
     where has_function_privilege('authenticated', oid, 'execute') $$,
  $$ select name from client_functions $$,
  'authenticated may execute exactly the client functions'
);

select is_empty(
  $$ select name from tests.public_functions()
     where name in (select name from service_functions)
       and not has_function_privilege('service_role', oid, 'execute') $$,
  'service_role may execute the service functions'
);

select is_empty(
  $$ select tablename from pg_tables where schemaname = 'public' and not rowsecurity $$,
  'RLS is enabled on every public table'
);

select is_empty(
  $$ select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname in ('public', 'private') and c.relkind in ('r', 'v', 'm', 'p', 'S')
       and (has_table_privilege('anon', c.oid, 'select')
         or has_table_privilege('anon', c.oid, 'insert')
         or has_table_privilege('anon', c.oid, 'update')
         or has_table_privilege('anon', c.oid, 'delete')) $$,
  'anon has no privilege on any table'
);

select is_empty(
  $$ select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname in ('public', 'private') and c.relkind in ('r', 'p')
       and (has_table_privilege('authenticated', c.oid, 'insert')
         or has_table_privilege('authenticated', c.oid, 'update')
         or has_table_privilege('authenticated', c.oid, 'delete')
         or has_table_privilege('authenticated', c.oid, 'truncate')) $$,
  'authenticated can only read tables, writes go through functions'
);

-- ── Calls ────────────────────────────────────────────────────

-- Arguments are nulls: the session check comes first, before any validation.
create temp table calls (name text, as_anon text, without_user text, without_profile text)
  on commit drop;
grant all on calls to anon, authenticated;

-- An auth user whose profile is gone (the trigger always creates one).
select tests.new_owner('ghost@test.kg') as ghost \gset
delete from public.profiles where id = :'ghost';

insert into calls (name)
select name from client_functions;

select tests.as_anon();
update calls set as_anon = tests.error_of(tests.call_with_nulls(name,
  (select nargs from tests.public_functions() f where f.name = calls.name)));

select tests.as_authenticated_without_user();
update calls set without_user = tests.error_of(tests.call_with_nulls(name,
  (select nargs from tests.public_functions() f where f.name = calls.name)));

select tests.login_as(:'ghost');
update calls set without_profile = tests.error_of(tests.call_with_nulls(name,
  (select nargs from tests.public_functions() f where f.name = calls.name)));
reset role;

select is_empty(
  $$ select name, as_anon from calls where as_anon <> '42501' $$,
  'anon gets "permission denied" from every client function'
);

select is_empty(
  $$ select name, without_user from calls where without_user <> 'PT401 not_authenticated' $$,
  'every client function rejects a request without a user with 401'
);

select is_empty(
  $$ select name, without_profile from calls where without_profile <> 'PT403 no_profile' $$,
  'every client function rejects a user without a profile with 403'
);

-- The service functions are not callable by app users.
create temp table service_calls (name text, as_user text) on commit drop;
grant all on service_calls to authenticated;
insert into service_calls (name) select name from service_functions;
select tests.new_owner('owner@test.kg') as owner \gset
select tests.login_as(:'owner');
update service_calls set as_user = tests.error_of(tests.call_with_nulls(name,
  (select nargs from tests.public_functions() f where f.name = service_calls.name)));
reset role;

select is_empty(
  $$ select name, as_user from service_calls where as_user <> '42501' $$,
  'an app user gets "permission denied" from every service function'
);

select is_empty(
  $$ select name from tests.public_functions()
     where name in (select name from service_functions)
       and has_function_privilege('authenticated', oid, 'execute') $$,
  'authenticated may execute no service function'
);

select * from finish();
rollback;
