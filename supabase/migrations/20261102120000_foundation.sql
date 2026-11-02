-- Foundation: schemas, default privileges, companies, profiles, registration.
-- Plan and rules: docs/supabase-plan.md.

-- ── Privileges ───────────────────────────────────────────────

-- Helpers, triggers and service tables. PostgREST does not expose this schema;
-- `authenticated` only needs it for the helpers that RLS policies call.
create schema private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated, service_role;

-- No function is callable unless granted explicitly, and new tables give
-- clients nothing: reads are granted per table, writes go through RPCs.
alter default privileges revoke execute on functions from public;
alter default privileges in schema public revoke execute on functions from anon, authenticated;
alter default privileges in schema private revoke execute on functions from anon, authenticated;
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;

-- ── Enums ────────────────────────────────────────────────────

create type public.user_role as enum ('owner', 'foreman', 'worker');

-- ── Tables ───────────────────────────────────────────────────

create table public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 200),
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  company_id uuid not null references public.companies (id),
  name text not null check (char_length(btrim(name)) between 1 and 200),
  email text not null,
  role public.user_role not null,
  -- Removed from the company: sees nothing, can call nothing, isn't listed.
  removed_at timestamptz,
  created_at timestamptz not null default now()
);

create index profiles_company_id_idx on public.profiles (company_id);

alter table public.companies enable row level security;
alter table public.profiles enable row level security;

revoke all on public.companies, public.profiles from anon, authenticated;
grant select on public.companies, public.profiles to authenticated;

-- ── Errors ───────────────────────────────────────────────────

-- PostgREST turns SQLSTATE `PTxxx` into HTTP status xxx. [hint] is the
-- machine-readable reason, [message] is for logs only (like Failure.message).
create function private.fail(p_status int, p_hint text, p_message text default null)
returns void
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'PT' || p_status,
    message = coalesce(p_message, p_hint),
    hint = p_hint;
end;
$$;

-- ── Helpers ──────────────────────────────────────────────────

-- Company of the current active user, or null (anon, no profile, removed).
-- Security definer: RLS on profiles calls it, so it must not re-enter RLS.
create function private.company_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.company_id
  from public.profiles p
  where p.id = auth.uid() and p.removed_at is null
$$;

create function private.user_role()
returns public.user_role
language sql
stable
security definer
set search_path = ''
as $$
  select p.role
  from public.profiles p
  where p.id = auth.uid() and p.removed_at is null
$$;

-- The first statement of every client function. 401 without a session,
-- 403 without an active profile; the client treats `account_removed` and
-- `no_profile` as an expired session (docs/supabase-plan.md).
create function private.require_user()
returns public.profiles
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me public.profiles;
begin
  if auth.uid() is null then
    perform private.fail(401, 'not_authenticated');
  end if;
  select * into me from public.profiles p where p.id = auth.uid();
  if not found then
    perform private.fail(403, 'no_profile');
  end if;
  if me.removed_at is not null then
    perform private.fail(403, 'account_removed');
  end if;
  return me;
end;
$$;

create function private.require_owner()
returns public.profiles
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me public.profiles := private.require_user();
begin
  if me.role <> 'owner' then
    perform private.fail(403, 'owner_only');
  end if;
  return me;
end;
$$;

-- Security invoker RPCs run these as `authenticated`, hence the grants. The
-- schema isn't exposed, so clients still can't call them directly.
revoke execute on function private.fail(int, text, text) from public, anon;
revoke execute on function private.require_user() from public, anon;
revoke execute on function private.require_owner() from public, anon;
revoke execute on function private.company_id() from public, anon;
revoke execute on function private.user_role() from public, anon;
grant execute on function private.fail(int, text, text) to authenticated;
grant execute on function private.require_user() to authenticated;
grant execute on function private.require_owner() to authenticated;
grant execute on function private.company_id() to authenticated;
grant execute on function private.user_role() to authenticated;

-- ── RLS ──────────────────────────────────────────────────────

create policy "own company" on public.companies
  for select to authenticated
  using (id = private.company_id());

-- Colleagues, active only: a removed member drops out of every list.
create policy "active colleagues" on public.profiles
  for select to authenticated
  using (company_id = private.company_id() and removed_at is null);

-- ── Registration ─────────────────────────────────────────────

-- Creates the profile of a new auth user, in the same transaction: an
-- exception here rejects the sign-up. Reads only `name` and `company_name`
-- from user metadata, which the user controls, and `invite_code` from app
-- metadata, which only the server sets (Edge Function `join`). Role and
-- company never come from metadata.
create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := nullif(btrim(new.raw_user_meta_data ->> 'name'), '');
  v_company_name text := nullif(btrim(new.raw_user_meta_data ->> 'company_name'), '');
  v_invite_code text := new.raw_app_meta_data ->> 'invite_code';
  v_company uuid;
  v_role public.user_role;
begin
  if v_name is null then
    perform private.fail(400, 'name_required');
  end if;

  if v_invite_code is not null then
    select r.out_company_id, r.out_role into v_company, v_role
    from private.redeem_invite(v_invite_code, new.id) r;
  elsif v_company_name is not null then
    insert into public.companies (name) values (v_company_name)
    returning id into v_company;
    v_role := 'owner';
  else
    perform private.fail(400, 'company_name_required');
  end if;

  insert into public.profiles (id, company_id, name, email, role)
  values (new.id, v_company, v_name, lower(new.email), v_role);
  return new;
end;
$$;

-- Invites arrive in the team stage; until then every code is unknown.
create function private.redeem_invite(p_code text, p_user_id uuid)
returns table (out_company_id uuid, out_role public.user_role)
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.fail(404, 'invalid_invite_code');
end;
$$;

create function private.sync_profile_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles set email = lower(new.email) where id = new.id;
  return new;
end;
$$;

revoke execute on function private.handle_new_user() from public, anon, authenticated;
revoke execute on function private.redeem_invite(text, uuid) from public, anon, authenticated;
revoke execute on function private.sync_profile_email() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

create trigger on_auth_user_email_changed
  after update of email on auth.users
  for each row when (old.email is distinct from new.email)
  execute function private.sync_profile_email();

-- ── JSON ─────────────────────────────────────────────────────

-- `User` of the client (lib/features/auth/domain/entities/user.dart).
create function private.user_json(p public.profiles)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p.id,
    'email', p.email,
    'name', p.name,
    'role', p.role,
    'companyId', p.company_id
  )
$$;

revoke execute on function private.user_json(public.profiles) from public, anon;
grant execute on function private.user_json(public.profiles) to authenticated;

-- ── RPC ──────────────────────────────────────────────────────

-- `{user, company}` of the signed-in user: after sign-in, sign-up and on
-- session restore (POST /auth/restore).
create function public.get_me()
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  me public.profiles := private.require_user();
begin
  return jsonb_build_object(
    'user', private.user_json(me),
    'company', (
      select jsonb_build_object('id', c.id, 'name', c.name)
      from public.companies c
      where c.id = me.company_id
    )
  );
end;
$$;

revoke execute on function public.get_me() from public, anon;
grant execute on function public.get_me() to authenticated;
