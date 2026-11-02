-- Realtime: who gets which chat event, and who may listen to a channel.
begin;
select plan(18);

select tests.new_owner('owner@a.kg', 'Асан', 'А') as owner \gset
select tests.company_of(:'owner') as company \gset
select tests.new_member(:'company', 'foreman', 'f1@a.kg', 'Бакыт') as f1 \gset
select tests.new_member(:'company', 'worker', 'w1@a.kg', 'Эрлан') as w1 \gset
select tests.new_member(:'company', 'worker', 'w2@a.kg', 'Азамат') as w2 \gset

select tests.login_as(:'owner');
select public.create_project('ЖК «Ала-Тоо»') ->> 'id' as p1 \gset
select public.update_project(:'p1', p_foreman_ids => array[:'f1'::uuid], p_worker_ids => array[:'w1'::uuid]) is not null as ok \gset
select public.get_chats() -> 0 ->> 'id' as c1 \gset

-- ── Messages ─────────────────────────────────────────────────

select tests.login_as(:'f1');
select public.send_message(:'c1', gen_random_uuid(), 'text', 'Бетон привезли') as m1 \gset
reset role;

select ok(
  (select count(*) = 1 from tests.events(:'owner', 'message.created') e
   where e = jsonb_build_object('type', 'message.created', 'chatId', :'c1', 'message', :'m1'::jsonb)),
  'message.created reaches a member with the message as get_messages shows it'
);
select ok(
  exists (select 1 from tests.events(:'f1', 'message.created') e where e -> 'message' ->> 'id' = :'m1'::jsonb ->> 'id'),
  'and the sender, for the other devices'
);
select is(
  (select count(*)::int from tests.events(:'w2', 'message.created')),
  0,
  'nothing reaches someone outside the chat'
);
select is(
  (select e -> 'chat' -> 'unreadCount' from tests.events(:'owner', 'chat.updated') e
   where e -> 'chat' -> 'lastMessage' ->> 'id' = :'m1'::jsonb ->> 'id'),
  '1'::jsonb,
  'chat.updated carries the unread count of each member'
);
select is(
  (select e -> 'chat' -> 'unreadCount' from tests.events(:'f1', 'chat.updated') e
   where e -> 'chat' -> 'lastMessage' ->> 'id' = :'m1'::jsonb ->> 'id' order by e -> 'chat' -> 'unreadCount' limit 1),
  '0'::jsonb,
  'the sender has nothing unread'
);

-- ── Read and listened ────────────────────────────────────────

select tests.login_as(:'owner');
select public.mark_read(:'c1', (:'m1'::jsonb ->> 'id')::uuid) is null as ok \gset
reset role;
select is(
  (select jsonb_agg(e) from tests.events(:'f1', 'message.status') e),
  jsonb_build_array(jsonb_build_object('type', 'message.status', 'chatId', :'c1',
    'upTo', :'m1'::jsonb ->> 'id', 'status', 'read')),
  'message.status tells the author their message was read'
);
select is((select count(*)::int from tests.events(:'owner', 'message.status')), 0, 'the reader gets no status');
select is(
  (select e -> 'chat' -> 'unreadCount' from tests.events(:'owner', 'chat.updated') e
   order by (e -> 'chat' -> 'unreadCount')::int limit 1),
  '0'::jsonb,
  'the reader''s other devices get the cleared unread count'
);

select tests.login_as(:'owner');
select public.mark_read(:'c1', (:'m1'::jsonb ->> 'id')::uuid) is null as ok \gset
reset role;
select is((select count(*)::int from tests.events(:'f1', 'message.status')), 1, 'reading again sends nothing');

select tests.voice(:'f1') as v1 \gset
select tests.login_as(:'f1');
select public.send_message(:'c1', gen_random_uuid(), 'voice', null, array[:'v1'::uuid]) ->> 'id' as vm \gset
select tests.login_as(:'w1');
select public.mark_listened(:'c1', :'vm') is null as ok \gset
reset role;
select is(
  (select jsonb_agg(e) from tests.events(:'f1', 'message.listened') e),
  jsonb_build_array(jsonb_build_object('type', 'message.listened', 'chatId', :'c1', 'messageId', :'vm', 'userId', :'w1')),
  'message.listened tells the author who played the voice note'
);

-- ── Membership ───────────────────────────────────────────────

select tests.login_as(:'owner');
select public.update_project(:'p1', p_worker_ids => array[]::uuid[]) is not null as ok \gset
reset role;
select is(
  (select jsonb_agg(e) from tests.events(:'w1', 'chat.removed') e),
  jsonb_build_array(jsonb_build_object('type', 'chat.removed', 'chatId', :'c1')),
  'chat.removed reaches the member taken off the project'
);
select ok(
  exists (select 1 from tests.events(:'owner', 'message.created') e
          where e -> 'message' ->> 'systemEvent' = 'memberRemoved' and e -> 'message' ->> 'subjectUserId' = :'w1'),
  'the others get the system message'
);
select ok(
  not exists (select 1 from tests.events(:'w1', 'message.created') e
              where e -> 'message' ->> 'systemEvent' = 'memberRemoved'),
  'the removed member does not'
);

select tests.login_as(:'owner');
select public.get_or_create_direct(:'w2') ->> 'id' as d1 \gset
select public.update_project(:'p1', p_name => 'ЖК «Ала-Тоо Резиденс»') is not null as ok \gset
reset role;
select ok(
  exists (select 1 from tests.events(:'w2', 'chat.updated') e
          where e -> 'chat' ->> 'id' = :'d1' and jsonb_array_length(e -> 'chat' -> 'participantIds') = 2),
  'a new direct chat reaches the other person as chat.updated'
);
select ok(
  exists (select 1 from tests.events(:'f1', 'chat.updated') e
          where e -> 'chat' ->> 'title' = 'ЖК «Ала-Тоо Резиденс»'),
  'renaming the project updates the chat title'
);

-- ── Channel access ───────────────────────────────────────────

select tests.login_as(:'f1');
select set_config('realtime.topic', 'user:' || :'f1', true) is not null as ok \gset
select ok((select count(*) > 0 from realtime.messages), 'a user reads the own channel');
select set_config('realtime.topic', 'user:' || :'owner', true) is not null as ok \gset
select is((select count(*)::int from realtime.messages), 0, 'and nobody else''s');

select tests.as_service();
select public.remove_member(:'owner', :'w2') as ok \gset
select tests.login_as(:'w2');
select set_config('realtime.topic', 'user:' || :'w2', true) is not null as ok \gset
select is((select count(*)::int from realtime.messages), 0, 'a removed member reads not even the own channel');

select * from finish();
rollback;
