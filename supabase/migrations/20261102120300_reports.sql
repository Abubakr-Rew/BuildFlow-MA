-- Uploads (attachments and Storage) and reports.

-- ── Tables ───────────────────────────────────────────────────

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  author_id uuid not null references public.profiles (id),
  text text not null default '' check (char_length(text) <= 4000),
  created_at timestamptz not null default now()
);

create index reports_project_id_idx on public.reports (project_id, created_at desc);

create type public.attachment_kind as enum ('photo', 'voice');

-- A file in Storage: created by create_upload, uploaded by the client
-- straight to Storage, then attached once to a report or a message by the
-- user who uploaded it.
create table public.attachments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id),
  company_id uuid not null references public.companies (id),
  kind public.attachment_kind not null,
  bucket text not null check (bucket in ('photos', 'voice')),
  path text not null unique,
  mime text not null,
  bytes int not null check (bytes > 0),
  width int,
  height int,
  duration_ms int,
  waveform smallint[],
  report_id uuid references public.reports (id) on delete cascade,
  -- The foreign key arrives with the messages table.
  message_id uuid,
  position smallint,
  taken_at timestamptz,
  created_at timestamptz not null default now(),
  constraint attachments_attached_once check (report_id is null or message_id is null),
  constraint attachments_photo check (
    kind <> 'photo' or (width > 0 and height > 0 and duration_ms is null and waveform is null)
  ),
  constraint attachments_voice check (
    kind <> 'voice' or (
      duration_ms between 1000 and 300000
      and array_length(waveform, 1) = 40
      and 0 <= all (waveform) and 100 >= all (waveform)
    )
  )
);

create index attachments_report_id_idx on public.attachments (report_id) where report_id is not null;
create index attachments_message_id_idx on public.attachments (message_id) where message_id is not null;
create index attachments_owner_id_idx on public.attachments (owner_id);

alter table public.reports enable row level security;
alter table public.attachments enable row level security;

revoke all on public.reports, public.attachments from anon, authenticated;
grant select on public.reports, public.attachments to authenticated;

-- ── Visibility ───────────────────────────────────────────────

create policy "reports of visible projects" on public.reports
  for select to authenticated
  using (private.can_see_project(project_id));

-- Its uploader while unattached; afterwards whoever sees the report (the
-- chat stage adds messages).
create function private.can_see_attachment(p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.attachments a
    where a.id = p_id
      and private.company_id() = a.company_id
      and (
        (a.owner_id = auth.uid() and a.report_id is null and a.message_id is null)
        or (a.report_id is not null and exists (
          select 1 from public.reports r
          where r.id = a.report_id and private.can_see_project(r.project_id)
        ))
      )
  )
$$;

revoke execute on function private.can_see_attachment(uuid) from public, anon;
grant execute on function private.can_see_attachment(uuid) to authenticated;

create policy "visible attachments" on public.attachments
  for select to authenticated
  using (private.can_see_attachment(id));

-- ── Storage ──────────────────────────────────────────────────

-- Private buckets; the type and size limits are Storage's own checks.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('photos', 'photos', false, 10 * 1024 * 1024, array['image/jpeg', 'image/png', 'image/webp']),
  ('voice', 'voice', false, 2 * 1024 * 1024, array['audio/mp4']);

-- The object at [p_name] is the caller's own attachment, not attached yet.
create function private.can_upload_object(p_bucket text, p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.company_id() is not null and exists (
    select 1 from public.attachments a
    where a.bucket = p_bucket and a.path = p_name
      and a.owner_id = auth.uid()
      and a.report_id is null and a.message_id is null
  )
$$;

create function private.can_read_object(p_bucket text, p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.attachments a
    where a.bucket = p_bucket and a.path = p_name and private.can_see_attachment(a.id)
  )
$$;

revoke execute on function private.can_upload_object(text, text) from public, anon;
revoke execute on function private.can_read_object(text, text) from public, anon;
grant execute on function private.can_upload_object(text, text) to authenticated;
grant execute on function private.can_read_object(text, text) to authenticated;

-- No update or delete policies: an uploaded file is never replaced.
create policy "buildflow: upload own attachments" on storage.objects
  for insert to authenticated
  with check (bucket_id in ('photos', 'voice') and private.can_upload_object(bucket_id, name));

create policy "buildflow: read visible attachments" on storage.objects
  for select to authenticated
  using (bucket_id in ('photos', 'voice') and private.can_read_object(bucket_id, name));

-- ── Uploads ──────────────────────────────────────────────────

-- POST /uploads. Checks the declared type and size, creates the attachment
-- and returns where to upload it: `POST /storage/v1/object/<bucket>/<path>`
-- with the user's token. 60 a minute per user.
create function public.create_upload(
  p_content_type text,
  p_bytes int,
  p_width int default null,
  p_height int default null,
  p_duration_ms int default null,
  p_waveform int[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me public.profiles := private.require_user();
  v_kind public.attachment_kind;
  v_bucket text;
  v_ext text;
  v_max_bytes int;
  v_id uuid := gen_random_uuid();
  v_path text;
begin
  case p_content_type
    when 'image/jpeg' then v_kind := 'photo'; v_ext := 'jpg';
    when 'image/png' then v_kind := 'photo'; v_ext := 'png';
    when 'image/webp' then v_kind := 'photo'; v_ext := 'webp';
    when 'audio/mp4' then v_kind := 'voice'; v_ext := 'm4a';
    else perform private.fail(400, 'unsupported_type');
  end case;

  if v_kind = 'photo' then
    v_bucket := 'photos';
    v_max_bytes := 10 * 1024 * 1024;
    if p_width is null or p_height is null or p_width not between 1 and 20000
      or p_height not between 1 and 20000 then
      perform private.fail(400, 'invalid_dimensions');
    end if;
  else
    v_bucket := 'voice';
    v_max_bytes := 2 * 1024 * 1024;
    if p_duration_ms is null or p_duration_ms not between 1000 and 300000 then
      perform private.fail(400, 'invalid_duration');
    end if;
    if p_waveform is null or cardinality(p_waveform) <> 40
      or exists (select 1 from unnest(p_waveform) v where v is null or v not between 0 and 100) then
      perform private.fail(400, 'invalid_waveform');
    end if;
  end if;

  if p_bytes is null or p_bytes <= 0 then
    perform private.fail(400, 'invalid_size');
  end if;
  if p_bytes > v_max_bytes then
    perform private.fail(400, 'too_large');
  end if;

  if not private.hit_rate_limit('upload:' || me.id, 60, interval '1 minute') then
    perform private.fail(429, 'too_many_requests');
  end if;

  v_path := me.company_id || '/' || me.id || '/' || v_id || '.' || v_ext;
  insert into public.attachments (
    id, owner_id, company_id, kind, bucket, path, mime, bytes, width, height, duration_ms, waveform
  ) values (
    v_id, me.id, me.company_id, v_kind, v_bucket, v_path, p_content_type, p_bytes,
    case when v_kind = 'photo' then p_width end,
    case when v_kind = 'photo' then p_height end,
    case when v_kind = 'voice' then p_duration_ms end,
    case when v_kind = 'voice' then p_waveform::smallint[] end
  );

  return jsonb_build_object('attachmentId', v_id, 'bucket', v_bucket, 'path', v_path);
end;
$$;

-- Locks the attachments [p_ids] for attaching, in order. Someone else's,
-- unknown or already attached → 403; not uploaded yet or of the wrong kind
-- → 400 (docs/api-contract.md, «Загрузка файлов»).
create function private.claim_attachments(
  p_ids uuid[],
  p_owner_id uuid,
  p_kind public.attachment_kind
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_attachment public.attachments;
begin
  if (select count(distinct id) from unnest(p_ids) as ids (id)) <> cardinality(p_ids)
    or array_position(p_ids, null) is not null then
    perform private.fail(400, 'invalid_attachments');
  end if;

  foreach v_id in array p_ids loop
    select * into v_attachment from public.attachments where id = v_id for update;
    if not found or v_attachment.owner_id <> p_owner_id
      or v_attachment.report_id is not null or v_attachment.message_id is not null then
      perform private.fail(403, 'attachment_forbidden');
    end if;
    if v_attachment.kind <> p_kind then
      perform private.fail(400, 'wrong_attachment_kind');
    end if;
    if not exists (
      select 1 from storage.objects o
      where o.bucket_id = v_attachment.bucket and o.name = v_attachment.path
    ) then
      perform private.fail(400, 'not_uploaded');
    end if;
  end loop;
end;
$$;

revoke execute on function private.claim_attachments(uuid[], uuid, public.attachment_kind)
  from public, anon, authenticated;

-- ── JSON ─────────────────────────────────────────────────────

-- Name of a user of the caller's company, removed or not: authors of old
-- reports and messages keep their names.
create function private.user_name(p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select p.name from public.profiles p
  where p.id = p_user_id and p.company_id = private.company_id()
$$;

revoke execute on function private.user_name(uuid) from public, anon;
grant execute on function private.user_name(uuid) to authenticated;

-- `Report` of the client. Photos carry `bucket` and `path` instead of a
-- `url`: the client signs them with Storage (docs/supabase-plan.md).
create function private.report_json(r public.reports)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', r.id,
    'projectId', r.project_id,
    'projectName', (select p.name from public.projects p where p.id = r.project_id),
    'authorId', r.author_id,
    'authorName', private.user_name(r.author_id),
    'text', r.text,
    'photos', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id,
        'bucket', a.bucket,
        'path', a.path,
        'takenAt', a.taken_at
      ) order by a.position)
      from public.attachments a
      where a.report_id = r.id
    ), '[]'::jsonb),
    'createdAt', r.created_at
  )
$$;

revoke execute on function private.report_json(public.reports) from public, anon;
grant execute on function private.report_json(public.reports) to authenticated;

-- ── Reports ──────────────────────────────────────────────────

-- GET /reports, GET /reports?projectId=: newest first.
create function public.get_reports(p_project_id uuid default null)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
begin
  perform private.require_user();
  return coalesce((
    select jsonb_agg(private.report_json(r) order by r.created_at desc, r.id)
    from public.reports r
    where p_project_id is null or r.project_id = p_project_id
  ), '[]'::jsonb);
end;
$$;

-- GET /reports/:id. Invisible counts as missing: 404.
create function public.get_report(p_id uuid)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_report public.reports;
begin
  perform private.require_user();
  select * into v_report from public.reports where id = p_id;
  if not found then
    perform private.fail(404, 'not_found', 'Report not found');
  end if;
  return private.report_json(v_report);
end;
$$;

-- POST /reports, by a foreman of the project. [p_photos]:
-- `[{attachmentId, takenAt}]`, up to 5, uploaded through create_upload.
create function public.submit_report(
  p_project_id uuid,
  p_text text default '',
  p_photos jsonb default '[]'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me public.profiles := private.require_user();
  v_text text := btrim(coalesce(p_text, ''));
  v_photos jsonb := coalesce(p_photos, '[]'::jsonb);
  v_ids uuid[];
  v_taken timestamptz[];
  v_report public.reports;
begin
  if me.role <> 'foreman' then
    perform private.fail(403, 'foreman_only');
  end if;
  if not exists (
    select 1 from public.projects p
    join public.project_members m on m.project_id = p.id and m.user_id = me.id
    where p.id = p_project_id
  ) then
    perform private.fail(404, 'not_found', 'Project not found');
  end if;
  if char_length(v_text) > 4000 then
    perform private.fail(400, 'invalid_text');
  end if;
  if jsonb_typeof(v_photos) <> 'array' then
    perform private.fail(400, 'invalid_photos');
  end if;
  if jsonb_array_length(v_photos) > 5 then
    perform private.fail(400, 'too_many_photos');
  end if;

  begin
    select
      coalesce(array_agg((e ->> 'attachmentId')::uuid order by i), '{}'),
      coalesce(array_agg((e ->> 'takenAt')::timestamptz order by i), '{}')
    into v_ids, v_taken
    from jsonb_array_elements(v_photos) with ordinality as photos (e, i);
  exception when invalid_text_representation or invalid_datetime_format
    or datetime_field_overflow or invalid_parameter_value then
    perform private.fail(400, 'invalid_photos');
  end;

  perform private.claim_attachments(v_ids, me.id, 'photo');

  insert into public.reports (project_id, author_id, text)
  values (p_project_id, me.id, v_text)
  returning * into v_report;

  update public.attachments a
  set report_id = v_report.id, position = photos.i, taken_at = v_taken[photos.i]
  from unnest(v_ids) with ordinality as photos (id, i)
  where a.id = photos.id;

  return private.report_json(v_report);
end;
$$;

revoke execute on function public.create_upload(text, int, int, int, int, int[]) from public, anon;
revoke execute on function public.get_reports(uuid) from public, anon;
revoke execute on function public.get_report(uuid) from public, anon;
revoke execute on function public.submit_report(uuid, text, jsonb) from public, anon;
grant execute on function public.create_upload(text, int, int, int, int, int[]) to authenticated;
grant execute on function public.get_reports(uuid) to authenticated;
grant execute on function public.get_report(uuid) to authenticated;
grant execute on function public.submit_report(uuid, text, jsonb) to authenticated;
