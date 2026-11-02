-- Realtime: chat events of docs/api-contract.md («Реальное время») sent from
-- the database to one private Broadcast channel per user, `user:<id>`, the
-- way the contract's STOMP queue /user/queue/chat works. The payload is the
-- contract's frame body: `{type, ...}` (realtime.send adds an `id`).

-- A user listens to the own channel only, while active in the company.
-- No insert policy: clients don't send to these channels.
create policy "buildflow: own user channel" on realtime.messages
  for select to authenticated
  using (
    realtime.topic() = 'user:' || auth.uid()::text
    and extension = 'broadcast'
    and private.company_id() is not null
  );

create function private.notify(p_user_id uuid, p_type text, p_body jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform realtime.send(
    jsonb_build_object('type', p_type) || p_body,
    p_type,
    'user:' || p_user_id::text,
    true
  );
end;
$$;

-- Active members of the chat: still in it and still in the company.
create function private.chat_audience(p_chat_id uuid)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select cm.user_id from public.chat_members cm
  join public.profiles p on p.id = cm.user_id
  where cm.chat_id = p_chat_id and cm.removed_at is null and p.removed_at is null
$$;

-- `chat.updated` with the chat as each member sees it (unreadCount).
create function private.notify_chat_updated(p_chat_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_chat public.chats;
  v_user uuid;
begin
  select * into v_chat from public.chats where id = p_chat_id;
  if not found then
    return;
  end if;
  for v_user in select private.chat_audience(p_chat_id) loop
    perform private.notify(v_user, 'chat.updated',
      jsonb_build_object('chat', private.chat_json(v_chat, v_user)));
  end loop;
end;
$$;

revoke execute on function private.notify(uuid, text, jsonb) from public, anon, authenticated;
revoke execute on function private.chat_audience(uuid) from public, anon, authenticated;
revoke execute on function private.notify_chat_updated(uuid) from public, anon, authenticated;

-- ── Triggers ─────────────────────────────────────────────────

-- message.created and chat.updated to every member, the sender included
-- (their other devices). Named to run after on_message_created, which
-- moves chats.updated_at.
create function private.on_message_notify()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid;
begin
  for v_user in select private.chat_audience(new.chat_id) loop
    perform private.notify(v_user, 'message.created', jsonb_build_object(
      'chatId', new.chat_id,
      'message', private.message_json(new, v_user)
    ));
  end loop;
  perform private.notify_chat_updated(new.chat_id);
  return null;
end;
$$;

-- Members joining, leaving or reading.
create function private.on_chat_member_notify()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_up_to uuid;
  v_user uuid;
begin
  if tg_op = 'INSERT'
    or (old.removed_at is not null and new.removed_at is null) then
    -- A new chat or a new member: everyone's participantIds change.
    perform private.notify_chat_updated(new.chat_id);
  elsif old.removed_at is null and new.removed_at is not null then
    perform private.notify(new.user_id, 'chat.removed', jsonb_build_object('chatId', new.chat_id));
    perform private.notify_chat_updated(new.chat_id);
  elsif new.last_read_seq > old.last_read_seq then
    select id into v_up_to from public.messages where seq = new.last_read_seq;
    -- message.status to the authors of the messages read just now.
    for v_user in
      select distinct m.sender_id from public.messages m
      where m.chat_id = new.chat_id
        and m.seq > old.last_read_seq and m.seq <= new.last_read_seq
        and m.sender_id is not null and m.sender_id <> new.user_id
        and m.sender_id in (select private.chat_audience(new.chat_id))
    loop
      perform private.notify(v_user, 'message.status', jsonb_build_object(
        'chatId', new.chat_id, 'upTo', v_up_to, 'status', 'read'));
    end loop;
    -- The reader's unreadCount on their other devices.
    if exists (select 1 from public.profiles p where p.id = new.user_id and p.removed_at is null) then
      perform private.notify(new.user_id, 'chat.updated', jsonb_build_object('chat',
        private.chat_json((select c from public.chats c where c.id = new.chat_id), new.user_id)));
    end if;
  end if;
  return null;
end;
$$;

create function private.on_listen_notify()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_message public.messages;
begin
  select * into v_message from public.messages where id = new.message_id;
  if v_message.sender_id in (select private.chat_audience(v_message.chat_id)) then
    perform private.notify(v_message.sender_id, 'message.listened', jsonb_build_object(
      'chatId', v_message.chat_id, 'messageId', new.message_id, 'userId', new.user_id));
  end if;
  return null;
end;
$$;

-- The project chat's title is the project name.
create function private.on_project_renamed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.notify_chat_updated((select id from public.chats where project_id = new.id));
  return null;
end;
$$;

revoke execute on function private.on_message_notify() from public, anon, authenticated;
revoke execute on function private.on_chat_member_notify() from public, anon, authenticated;
revoke execute on function private.on_listen_notify() from public, anon, authenticated;
revoke execute on function private.on_project_renamed() from public, anon, authenticated;

create trigger on_message_notify
  after insert on public.messages
  for each row execute function private.on_message_notify();

create trigger on_chat_member_notify
  after insert or update on public.chat_members
  for each row execute function private.on_chat_member_notify();

create trigger on_listen_notify
  after insert on public.message_listens
  for each row execute function private.on_listen_notify();

create trigger on_project_renamed
  after update of name on public.projects
  for each row when (old.name is distinct from new.name)
  execute function private.on_project_renamed();
