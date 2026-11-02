-- Projects and their teams.

create type public.project_status as enum ('active', 'paused', 'finished');

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id),
  name text not null check (char_length(btrim(name)) between 1 and 200),
  address text not null default '' check (char_length(address) <= 300),
  status public.project_status not null default 'active',
  progress int not null default 0 check (progress between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index projects_company_id_idx on public.projects (company_id);

-- Foremen and workers of a project; which list a member is in follows from
-- the role in the profile. Owners see every project and aren't listed.
create table public.project_members (
  project_id uuid not null references public.projects (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  added_at timestamptz not null default now(),
  primary key (project_id, user_id)
);

create index project_members_user_id_idx on public.project_members (user_id);

alter table public.projects enable row level security;
alter table public.project_members enable row level security;

revoke all on public.projects, public.project_members from anon, authenticated;
grant select on public.projects, public.project_members to authenticated;

-- ── Visibility ───────────────────────────────────────────────

create function private.is_project_member(p_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.project_members m
    where m.project_id = p_project_id and m.user_id = auth.uid()
  )
$$;

-- Like canSeeProject() in the client: owners see the whole company,
-- foremen and workers the projects they're on.
create function private.can_see_project(p_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.projects p
    where p.id = p_project_id
      and p.company_id = private.company_id()
      and (private.user_role() = 'owner' or private.is_project_member(p.id))
  )
$$;

revoke execute on function private.is_project_member(uuid) from public, anon;
revoke execute on function private.can_see_project(uuid) from public, anon;
grant execute on function private.is_project_member(uuid) to authenticated;
grant execute on function private.can_see_project(uuid) to authenticated;

create policy "visible projects" on public.projects
  for select to authenticated
  using (
    company_id = private.company_id()
    and (private.user_role() = 'owner' or private.is_project_member(id))
  );

create policy "teams of visible projects" on public.project_members
  for select to authenticated
  using (private.can_see_project(project_id));

-- ── JSON ─────────────────────────────────────────────────────

-- `Project` of the client (lib/features/projects/domain/entities/project.dart).
create function private.project_json(p public.projects)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p.id,
    'name', p.name,
    'address', p.address,
    'status', p.status,
    'companyId', p.company_id,
    'foremanIds', coalesce((
      select jsonb_agg(m.user_id order by m.added_at, m.user_id)
      from public.project_members m
      join public.profiles u on u.id = m.user_id
      where m.project_id = p.id and u.role = 'foreman'
    ), '[]'::jsonb),
    'workerIds', coalesce((
      select jsonb_agg(m.user_id order by m.added_at, m.user_id)
      from public.project_members m
      join public.profiles u on u.id = m.user_id
      where m.project_id = p.id and u.role = 'worker'
    ), '[]'::jsonb),
    'progress', p.progress
  )
$$;

revoke execute on function private.project_json(public.projects) from public, anon;
grant execute on function private.project_json(public.projects) to authenticated;

-- ── Helpers for writes ───────────────────────────────────────

-- The project of the owner's company, locked for the update; 404 otherwise.
create function private.owned_project(p_project_id uuid, p_company_id uuid)
returns public.projects
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_project public.projects;
begin
  select * into v_project from public.projects
  where id = p_project_id and company_id = p_company_id
  for update;
  if not found then
    perform private.fail(404, 'not_found', 'Project not found');
  end if;
  return v_project;
end;
$$;

-- Makes the [p_role] list of the project exactly [p_user_ids]. Every id must
-- be an active member of the company with that role, otherwise 400.
create function private.set_project_members(
  p_project public.projects,
  p_role public.user_role,
  p_user_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from unnest(p_user_ids) as ids (id)
    where not exists (
      select 1 from public.profiles u
      where u.id = ids.id
        and u.company_id = p_project.company_id
        and u.role = p_role
        and u.removed_at is null
    )
  ) then
    perform private.fail(400, 'invalid_member', 'Not an active ' || p_role || ' of the company');
  end if;

  delete from public.project_members m
  using public.profiles u
  where m.project_id = p_project.id
    and u.id = m.user_id
    and u.role = p_role
    and m.user_id <> all (p_user_ids);

  insert into public.project_members (project_id, user_id)
  select distinct p_project.id, ids.id from unnest(p_user_ids) as ids (id)
  on conflict do nothing;
end;
$$;

revoke execute on function private.owned_project(uuid, uuid) from public, anon, authenticated;
revoke execute on function private.set_project_members(public.projects, public.user_role, uuid[])
  from public, anon, authenticated;

create function private.validated_project_name(p_name text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_name is null or char_length(btrim(p_name)) not between 1 and 200 then
    perform private.fail(400, 'invalid_name');
  end if;
  return btrim(p_name);
end;
$$;

create function private.validated_address(p_address text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
begin
  if char_length(btrim(coalesce(p_address, ''))) > 300 then
    perform private.fail(400, 'invalid_address');
  end if;
  return btrim(coalesce(p_address, ''));
end;
$$;

revoke execute on function private.validated_project_name(text) from public, anon, authenticated;
revoke execute on function private.validated_address(text) from public, anon, authenticated;

-- ── RPC: reads ───────────────────────────────────────────────

-- GET /projects: the projects the user sees.
create function public.get_projects()
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
begin
  perform private.require_user();
  return coalesce((
    select jsonb_agg(private.project_json(p) order by p.created_at, p.id)
    from public.projects p
  ), '[]'::jsonb);
end;
$$;

-- GET /projects/:id. Invisible counts as missing: 404.
create function public.get_project(p_id uuid)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_project public.projects;
begin
  perform private.require_user();
  select * into v_project from public.projects where id = p_id;
  if not found then
    perform private.fail(404, 'not_found', 'Project not found');
  end if;
  return private.project_json(v_project);
end;
$$;

-- ── RPC: writes (owner only) ─────────────────────────────────

-- POST /projects.
create function public.create_project(p_name text, p_address text default '')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me public.profiles := private.require_owner();
  v_project public.projects;
begin
  insert into public.projects (company_id, name, address)
  values (me.company_id, private.validated_project_name(p_name), private.validated_address(p_address))
  returning * into v_project;
  return private.project_json(v_project);
end;
$$;

-- PUT /projects/:id as a partial update: a null argument keeps the field,
-- so a status change can't overwrite a concurrent team change.
create function public.update_project(
  p_id uuid,
  p_name text default null,
  p_address text default null,
  p_status text default null,
  p_progress int default null,
  p_foreman_ids uuid[] default null,
  p_worker_ids uuid[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me public.profiles := private.require_owner();
  v_project public.projects := private.owned_project(p_id, me.company_id);
begin
  if p_status is not null and p_status not in ('active', 'paused', 'finished') then
    perform private.fail(400, 'invalid_status');
  end if;
  if p_progress is not null and p_progress not between 0 and 100 then
    perform private.fail(400, 'invalid_progress');
  end if;

  update public.projects set
    name = case when p_name is null then name else private.validated_project_name(p_name) end,
    address = case when p_address is null then address else private.validated_address(p_address) end,
    status = coalesce(p_status::public.project_status, status),
    progress = coalesce(p_progress, progress),
    updated_at = now()
  where id = v_project.id
  returning * into v_project;

  if p_foreman_ids is not null then
    perform private.set_project_members(v_project, 'foreman', p_foreman_ids);
  end if;
  if p_worker_ids is not null then
    perform private.set_project_members(v_project, 'worker', p_worker_ids);
  end if;

  return private.project_json(v_project);
end;
$$;

-- POST /projects/:id/foremen.
create function public.assign_foreman(p_project_id uuid, p_foreman_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me public.profiles := private.require_owner();
  v_project public.projects := private.owned_project(p_project_id, me.company_id);
begin
  if not exists (
    select 1 from public.profiles u
    where u.id = p_foreman_id and u.company_id = me.company_id
      and u.role = 'foreman' and u.removed_at is null
  ) then
    perform private.fail(400, 'invalid_member', 'Not an active foreman of the company');
  end if;
  insert into public.project_members (project_id, user_id)
  values (v_project.id, p_foreman_id)
  on conflict do nothing;
  return private.project_json(v_project);
end;
$$;

-- DELETE /projects/:id/foremen/:foremanId.
create function public.remove_foreman(p_project_id uuid, p_foreman_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me public.profiles := private.require_owner();
  v_project public.projects := private.owned_project(p_project_id, me.company_id);
begin
  delete from public.project_members m
  using public.profiles u
  where m.project_id = v_project.id and m.user_id = p_foreman_id
    and u.id = m.user_id and u.role = 'foreman';
  return private.project_json(v_project);
end;
$$;

revoke execute on function public.get_projects() from public, anon;
revoke execute on function public.get_project(uuid) from public, anon;
revoke execute on function public.create_project(text, text) from public, anon;
revoke execute on function public.update_project(uuid, text, text, text, int, uuid[], uuid[]) from public, anon;
revoke execute on function public.assign_foreman(uuid, uuid) from public, anon;
revoke execute on function public.remove_foreman(uuid, uuid) from public, anon;
grant execute on function public.get_projects() to authenticated;
grant execute on function public.get_project(uuid) to authenticated;
grant execute on function public.create_project(text, text) to authenticated;
grant execute on function public.update_project(uuid, text, text, text, int, uuid[], uuid[]) to authenticated;
grant execute on function public.assign_foreman(uuid, uuid) to authenticated;
grant execute on function public.remove_foreman(uuid, uuid) to authenticated;
