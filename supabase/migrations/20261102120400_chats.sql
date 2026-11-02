-- Chats: project chats that follow the project team, direct chats,
-- messages with photos and voice notes, read marks and listens.

-- ── Tables ───────────────────────────────────────────────────

create type public.chat_type as enum ('direct', 'project');
create type public.message_kind as enum ('text', 'photo', 'voice', 'report', 'system');
create type public.chat_system_event as enum ('memberAdded', 'memberRemoved');

create table public.chats (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id),
  type public.chat_type not null,
  project_id uuid unique references public.projects (id) on delete cascade,
  -- Both user ids, smaller first: one direct chat per pair.
  direct_key text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chats_project check ((type = 'project') = (project_id is not null)),
  constraint chats_direct check ((type = 'direct') = (direct_key is not null))
);

-- A removed row (removed_at) keeps the read mark: someone put back on the
-- project sees the whole history again.
create table public.chat_members (
  chat_id uuid not null references public.chats (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  removed_at timestamptz,
  -- Read up to the message with this seq, inclusive.
  last_read_seq bigint not null default 0,
  primary key (chat_id, user_id)
);

create index chat_members_user_id_idx on public.chat_members (user_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  -- Order of messages, for pages (before / after) and read marks.
  seq bigint generated always as identity unique,
  chat_id uuid not null references public.chats (id) on delete cascade,
  -- Null for system messages; `"system"` in JSON, as systemSenderId.
  sender_id uuid references public.profiles (id),
  client_id uuid not null default gen_random_uuid(),
  kind public.message_kind not null,
  text text check (char_length(text) <= 4000),
  system_event public.chat_system_event,
  subject_user_id uuid references public.profiles (id),
  report_id uuid references public.reports (id) on delete set null,
  created_at timestamptz not null default now(),
  -- A retry with the same clientId returns the message instead of a copy.
  constraint messages_client_id unique (sender_id, client_id),
  constraint messages_system check ((kind = 'system') = (sender_id is null)),
  constraint messages_system_event check (
    kind <> 'system' or (system_event is not null and subject_user_id is not null)
  )
);

create index messages_chat_id_seq_idx on public.messages (chat_id, seq);

alter table public.attachments
  add constraint attachments_message_id_fkey
  foreign key (message_id) references public.messages (id) on delete cascade;

create table public.message_listens (
  message_id uuid not null references public.messages (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  listened_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

alter table public.chats enable row level security;
alter table public.chat_members enable row level security;
alter table public.messages enable row level security;
alter table public.message_listens enable row level security;

revoke all on public.chats, public.chat_members, public.messages, public.message_listens
  from anon, authenticated;
grant select on public.chats, public.chat_members, public.messages, public.message_listens
  to authenticated;

-- ── Access ───────────────────────────────────────────────────

create function private.is_chat_member(p_chat_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.company_id() is not null and exists (
    select 1 from public.chat_members m
    where m.chat_id = p_chat_id and m.user_id = auth.uid() and m.removed_at is null
  )
$$;

-- 404 for a chat that doesn't exist (or is another company's), 403 for one
-- the user isn't in (any more).
create function private.require_chat(p_chat_id uuid)
returns public.chats
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_chat public.chats;
begin
  select * into v_chat from public.chats
  where id = p_chat_id and company_id = private.company_id();
  if not found then
    perform private.fail(404, 'not_found', 'Chat not found');
  end if;
  if not private.is_chat_member(p_chat_id) then
    perform private.fail(403, 'forbidden', 'Not a member of the chat');
  end if;
  return v_chat;
end;
$$;

revoke execute on function private.is_chat_member(uuid) from public, anon;
revoke execute on function private.require_chat(uuid) from public, anon;
grant execute on function private.is_chat_member(uuid) to authenticated;
grant execute on function private.require_chat(uuid) to authenticated;

create policy "own chats" on public.chats
  for select to authenticated using (private.is_chat_member(id));
create policy "members of own chats" on public.chat_members
  for select to authenticated using (private.is_chat_member(chat_id));
create policy "messages of own chats" on public.messages
  for select to authenticated using (private.is_chat_member(chat_id));
create policy "own listens" on public.message_listens
  for select to authenticated using (user_id = auth.uid());

-- Attachments of messages are visible to the chat members.
create or replace function private.can_see_attachment(p_id uuid)
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
        or (a.message_id is not null and exists (
          select 1 from public.messages m
          where m.id = a.message_id and private.is_chat_member(m.chat_id)
        ))
      )
  )
$$;

-- ── Membership ───────────────────────────────────────────────

create function private.post_system_message(
  p_chat_id uuid,
  p_event public.chat_system_event,
  p_subject_id uuid
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.messages (chat_id, kind, system_event, subject_user_id)
  values (p_chat_id, 'system', p_event, p_subject_id)
$$;

-- Adds or brings back [p_user_id]; a system message if [p_announce].
create function private.add_chat_member(p_chat_id uuid, p_user_id uuid, p_announce boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.chat_members (chat_id, user_id)
  values (p_chat_id, p_user_id)
  on conflict (chat_id, user_id) do update
    set removed_at = null, joined_at = now()
    where chat_members.removed_at is not null;
  if found and p_announce then
    perform private.post_system_message(p_chat_id, 'memberAdded', p_user_id);
  end if;
end;
$$;

create function private.remove_chat_member(p_chat_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.chat_members set removed_at = now()
  where chat_id = p_chat_id and user_id = p_user_id and removed_at is null;
  if found then
    perform private.post_system_message(p_chat_id, 'memberRemoved', p_user_id);
  end if;
end;
$$;

revoke execute on function private.post_system_message(uuid, public.chat_system_event, uuid)
  from public, anon, authenticated;
revoke execute on function private.add_chat_member(uuid, uuid, boolean) from public, anon, authenticated;
revoke execute on function private.remove_chat_member(uuid, uuid) from public, anon, authenticated;

-- A project gets its chat with every owner of the company in it.
create function private.on_project_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_chat uuid;
begin
  insert into public.chats (company_id, type, project_id)
  values (new.company_id, 'project', new.id)
  returning id into v_chat;

  insert into public.chat_members (chat_id, user_id)
  select v_chat, p.id from public.profiles p
  where p.company_id = new.company_id and p.role = 'owner' and p.removed_at is null;
  return null;
end;
$$;

-- The project team is the chat team: owners + project_members.
create function private.on_project_member_changed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_chat uuid;
begin
  select id into v_chat from public.chats
  where project_id = coalesce(new.project_id, old.project_id);
  if v_chat is null then
    return null;
  end if;
  if tg_op = 'INSERT' then
    perform private.add_chat_member(v_chat, new.user_id, true);
  else
    perform private.remove_chat_member(v_chat, old.user_id);
  end if;
  return null;
end;
$$;

-- A member removed from the company leaves the project chats they are
-- still in (owners; the others left with their projects). Direct chats stay
-- with the other person, read-only.
create function private.on_profile_removed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_chat uuid;
begin
  for v_chat in
    select m.chat_id from public.chat_members m
    join public.chats c on c.id = m.chat_id
    where m.user_id = new.id and m.removed_at is null and c.type = 'project'
  loop
    perform private.remove_chat_member(v_chat, new.id);
  end loop;
  return null;
end;
$$;

-- A new owner joins every project chat of the company.
create function private.on_owner_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.chat_members (chat_id, user_id)
  select c.id, new.id from public.chats c
  where c.company_id = new.company_id and c.type = 'project'
  on conflict do nothing;
  return null;
end;
$$;

create function private.on_message_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.chats set updated_at = new.created_at where id = new.chat_id;
  return null;
end;
$$;

revoke execute on function private.on_project_created() from public, anon, authenticated;
revoke execute on function private.on_project_member_changed() from public, anon, authenticated;
revoke execute on function private.on_profile_removed() from public, anon, authenticated;
revoke execute on function private.on_owner_created() from public, anon, authenticated;
revoke execute on function private.on_message_created() from public, anon, authenticated;

create trigger on_project_created
  after insert on public.projects
  for each row execute function private.on_project_created();

create trigger on_project_member_changed
  after insert or delete on public.project_members
  for each row execute function private.on_project_member_changed();

create trigger on_profile_removed
  after update of removed_at on public.profiles
  for each row when (old.removed_at is null and new.removed_at is not null)
  execute function private.on_profile_removed();

create trigger on_owner_created
  after insert on public.profiles
  for each row when (new.role = 'owner')
  execute function private.on_owner_created();

create trigger on_message_created
  after insert on public.messages
  for each row execute function private.on_message_created();

-- ── JSON ─────────────────────────────────────────────────────
-- For a viewer: status, listened and unreadCount depend on who asks. Run
-- under RLS for the client and without it in triggers, which build the
-- same JSON for every recipient.

-- `MessageAttachment` of the client, with `bucket` and `path` for signing.
create function private.attachment_json(a public.attachments)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'id', a.id,
    'bucket', a.bucket,
    'path', a.path,
    'mime', a.mime,
    'width', a.width,
    'height', a.height,
    'durationMs', a.duration_ms,
    'waveform', to_jsonb(a.waveform)
  ))
$$;

-- `Message` of the client. `read` once another member has read it, for the
-- sender; `listened` whether the viewer has played someone else's voice note.
create function private.message_json(m public.messages, p_viewer uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', m.id,
    'clientId', m.client_id,
    'chatId', m.chat_id,
    'senderId', coalesce(m.sender_id::text, 'system'),
    'kind', m.kind,
    'text', m.text,
    'createdAt', m.created_at,
    'status', case
      when m.sender_id = p_viewer and exists (
        select 1 from public.chat_members cm
        where cm.chat_id = m.chat_id and cm.user_id <> p_viewer and cm.last_read_seq >= m.seq
      ) then 'read'
      else 'sent'
    end,
    'attachments', coalesce((
      select jsonb_agg(private.attachment_json(a) order by a.position)
      from public.attachments a where a.message_id = m.id
    ), '[]'::jsonb),
    'listened', m.kind = 'voice' and m.sender_id <> p_viewer and exists (
      select 1 from public.message_listens l
      where l.message_id = m.id and l.user_id = p_viewer
    ),
    'reportId', m.report_id,
    'systemEvent', m.system_event,
    'subjectUserId', m.subject_user_id
  )
$$;

-- `Chat` of the client. Title: the project name, empty for a direct chat.
create function private.chat_json(c public.chats, p_viewer uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', c.id,
    'type', c.type,
    'projectId', c.project_id,
    'title', coalesce((select p.name from public.projects p where p.id = c.project_id), ''),
    'participantIds', coalesce((
      select jsonb_agg(cm.user_id order by cm.joined_at, cm.user_id)
      from public.chat_members cm
      where cm.chat_id = c.id and cm.removed_at is null
    ), '[]'::jsonb),
    'updatedAt', c.updated_at,
    'unreadCount', (
      select count(*) from public.messages m
      where m.chat_id = c.id
        and m.kind <> 'system'
        and m.sender_id is distinct from p_viewer
        and m.seq > coalesce((
          select cm.last_read_seq from public.chat_members cm
          where cm.chat_id = c.id and cm.user_id = p_viewer
        ), 0)
    ),
    'lastMessage', (
      select private.message_json(m, p_viewer) from public.messages m
      where m.chat_id = c.id order by m.seq desc limit 1
    )
  )
$$;

revoke execute on function private.attachment_json(public.attachments) from public, anon;
revoke execute on function private.message_json(public.messages, uuid) from public, anon;
revoke execute on function private.chat_json(public.chats, uuid) from public, anon;
grant execute on function private.attachment_json(public.attachments) to authenticated;
grant execute on function private.message_json(public.messages, uuid) to authenticated;
grant execute on function private.chat_json(public.chats, uuid) to authenticated;

-- ── RPC: reads ───────────────────────────────────────────────

-- GET /chats: the user's chats, most recently active first.
create function public.get_chats()
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  me public.profiles := private.require_user();
begin
  return coalesce((
    select jsonb_agg(private.chat_json(c, me.id) order by c.updated_at desc, c.id)
    from public.chats c
  ), '[]'::jsonb);
end;
$$;

-- GET /chats/:id/messages?before=&after=&limit=, oldest first. `after`
-- returns at most 500, the newest of them, with truncated = true if more
-- were missed: the client then reloads the chat.
create function public.get_messages(
  p_chat_id uuid,
  p_before uuid default null,
  p_after uuid default null,
  p_limit int default 50
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  me public.profiles := private.require_user();
  v_limit int := coalesce(p_limit, 50);
  v_seq bigint;
  v_page uuid[];
  v_truncated boolean := false;
begin
  perform private.require_chat(p_chat_id);
  if v_limit not between 1 and 100 then
    perform private.fail(400, 'invalid_limit');
  end if;
  if p_before is not null and p_after is not null then
    perform private.fail(400, 'before_and_after');
  end if;

  if coalesce(p_before, p_after) is not null then
    select seq into v_seq from public.messages
    where id = coalesce(p_before, p_after) and chat_id = p_chat_id;
    if v_seq is null then
      perform private.fail(404, 'not_found', 'Message not found');
    end if;
  end if;

  if p_after is not null then
    v_truncated := (
      select count(*) from (
        select 1 from public.messages
        where chat_id = p_chat_id and seq > v_seq
        limit 501
      ) newer
    ) > 500;
    v_page := array(
      select id from public.messages
      where chat_id = p_chat_id and seq > v_seq
      order by seq desc limit 500
    );
  else
    v_page := array(
      select id from public.messages
      where chat_id = p_chat_id and (v_seq is null or seq < v_seq)
      order by seq desc limit v_limit
    );
  end if;

  return jsonb_build_object(
    'messages', coalesce((
      select jsonb_agg(private.message_json(m, me.id) order by m.seq)
      from public.messages m
      where m.id = any (v_page)
    ), '[]'::jsonb),
    'truncated', v_truncated
  );
end;
$$;

-- ── RPC: writes ──────────────────────────────────────────────

-- POST /chats/:id/messages. Idempotent per (sender, clientId): a retry gets
-- the message created by the first attempt. text: 1–4000; photo: 1–10
-- attachments and an optional caption; voice: one attachment, no text.
-- 30 a minute per user. Marks the chat read by the sender up to it.
create function public.send_message(
  p_chat_id uuid,
  p_client_id uuid,
  p_kind text,
  p_text text default null,
  p_attachment_ids uuid[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me public.profiles := private.require_user();
  v_chat public.chats;
  v_text text := nullif(btrim(coalesce(p_text, '')), '');
  v_ids uuid[] := coalesce(p_attachment_ids, '{}');
  v_message public.messages;
begin
  if p_client_id is null then
    perform private.fail(400, 'invalid_client_id');
  end if;

  select * into v_message from public.messages
  where sender_id = me.id and client_id = p_client_id;
  if found then
    if v_message.chat_id is distinct from p_chat_id then
      perform private.fail(400, 'client_id_reused');
    end if;
    return private.message_json(v_message, me.id);
  end if;

  v_chat := private.require_chat(p_chat_id);
  -- The other person of a direct chat left the company: read-only.
  if v_chat.type = 'direct' and exists (
    select 1 from public.chat_members cm
    join public.profiles p on p.id = cm.user_id
    where cm.chat_id = v_chat.id and p.removed_at is not null
  ) then
    perform private.fail(403, 'forbidden', 'The other member has left the company');
  end if;

  case p_kind
    when 'text' then
      if v_text is null or cardinality(v_ids) > 0 then
        perform private.fail(400, 'invalid_text');
      end if;
    when 'photo' then
      if cardinality(v_ids) not between 1 and 10 then
        perform private.fail(400, 'invalid_attachments');
      end if;
    when 'voice' then
      if cardinality(v_ids) <> 1 then
        perform private.fail(400, 'invalid_attachments');
      end if;
      if v_text is not null then
        perform private.fail(400, 'invalid_text');
      end if;
    else
      perform private.fail(400, 'invalid_kind');
  end case;
  if char_length(v_text) > 4000 then
    perform private.fail(400, 'invalid_text');
  end if;

  if not private.hit_rate_limit('message:' || me.id, 30, interval '1 minute') then
    perform private.fail(429, 'too_many_requests');
  end if;

  if p_kind <> 'text' then
    perform private.claim_attachments(v_ids, me.id, p_kind::public.attachment_kind);
  end if;

  insert into public.messages (chat_id, sender_id, client_id, kind, text)
  values (v_chat.id, me.id, p_client_id, p_kind::public.message_kind, v_text)
  returning * into v_message;

  update public.attachments a
  set message_id = v_message.id, position = ids.i
  from unnest(v_ids) with ordinality as ids (id, i)
  where a.id = ids.id;

  update public.chat_members set last_read_seq = greatest(last_read_seq, v_message.seq)
  where chat_id = v_chat.id and user_id = me.id;

  return private.message_json(v_message, me.id);
end;
$$;

-- POST /chats/direct: the direct chat with a colleague, created once.
create function public.get_or_create_direct(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me public.profiles := private.require_user();
  v_key text;
  v_chat public.chats;
begin
  if p_user_id = me.id then
    perform private.fail(400, 'self_chat');
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = p_user_id and p.company_id = me.company_id and p.removed_at is null
  ) then
    perform private.fail(404, 'not_found', 'User not found');
  end if;

  v_key := least(me.id, p_user_id)::text || ':' || greatest(me.id, p_user_id)::text;
  insert into public.chats (company_id, type, direct_key)
  values (me.company_id, 'direct', v_key)
  on conflict (direct_key) do nothing
  returning * into v_chat;

  if v_chat.id is null then
    select * into v_chat from public.chats where direct_key = v_key;
  else
    perform private.add_chat_member(v_chat.id, me.id, false);
    perform private.add_chat_member(v_chat.id, p_user_id, false);
  end if;
  return private.chat_json(v_chat, me.id);
end;
$$;

-- POST /chats/:id/read: read up to the message, inclusive; only forward.
create function public.mark_read(p_chat_id uuid, p_up_to uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me public.profiles := private.require_user();
  v_seq bigint;
begin
  perform private.require_chat(p_chat_id);
  select seq into v_seq from public.messages where id = p_up_to and chat_id = p_chat_id;
  if v_seq is null then
    perform private.fail(404, 'not_found', 'Message not found');
  end if;
  update public.chat_members set last_read_seq = v_seq
  where chat_id = p_chat_id and user_id = me.id and last_read_seq < v_seq;
end;
$$;

-- POST /chats/:id/messages/:messageId/listened: someone else's voice note.
create function public.mark_listened(p_chat_id uuid, p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me public.profiles := private.require_user();
begin
  perform private.require_chat(p_chat_id);
  if not exists (
    select 1 from public.messages m
    where m.id = p_message_id and m.chat_id = p_chat_id
      and m.kind = 'voice' and m.sender_id <> me.id
  ) then
    perform private.fail(404, 'not_found', 'Voice message not found');
  end if;
  insert into public.message_listens (message_id, user_id)
  values (p_message_id, me.id)
  on conflict do nothing;
end;
$$;

revoke execute on function public.get_chats() from public, anon;
revoke execute on function public.get_messages(uuid, uuid, uuid, int) from public, anon;
revoke execute on function public.send_message(uuid, uuid, text, text, uuid[]) from public, anon;
revoke execute on function public.get_or_create_direct(uuid) from public, anon;
revoke execute on function public.mark_read(uuid, uuid) from public, anon;
revoke execute on function public.mark_listened(uuid, uuid) from public, anon;
grant execute on function public.get_chats() to authenticated;
grant execute on function public.get_messages(uuid, uuid, uuid, int) to authenticated;
grant execute on function public.send_message(uuid, uuid, text, text, uuid[]) to authenticated;
grant execute on function public.get_or_create_direct(uuid) to authenticated;
grant execute on function public.mark_read(uuid, uuid) to authenticated;
grant execute on function public.mark_listened(uuid, uuid) to authenticated;
