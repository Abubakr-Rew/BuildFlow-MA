-- Chats: project chat follows the team, messages, read marks, listens,
-- pages, direct chats, removal from the company.
begin;
select plan(59);

select tests.new_owner('owner@a.kg', 'Асан', 'А') as owner \gset
select tests.company_of(:'owner') as company \gset
select tests.new_member(:'company', 'foreman', 'f1@a.kg', 'Бакыт') as f1 \gset
select tests.new_member(:'company', 'worker', 'w1@a.kg', 'Эрлан') as w1 \gset
select tests.new_member(:'company', 'worker', 'w2@a.kg', 'Азамат') as w2 \gset
select tests.new_owner('owner@b.kg', 'Чужой', 'Б') as owner_b \gset

-- ── Project chat ─────────────────────────────────────────────

select tests.login_as(:'owner');
select public.create_project('ЖК «Ала-Тоо»') ->> 'id' as p1 \gset
select public.get_chats() -> 0 as chat \gset
select :'chat'::jsonb ->> 'id' as c1 \gset

select is(
  :'chat'::jsonb - 'id' - 'updatedAt',
  jsonb_build_object('type', 'project', 'projectId', :'p1', 'title', 'ЖК «Ала-Тоо»',
    'participantIds', jsonb_build_array(:'owner'), 'unreadCount', 0, 'lastMessage', null),
  'a project gets its chat with the owner in it'
);

select public.update_project(:'p1', p_foreman_ids => array[:'f1'::uuid], p_worker_ids => array[:'w1'::uuid]) is not null as ok \gset
select is(
  tests.sorted(public.get_chats() -> 0 -> 'participantIds'),
  tests.sorted(jsonb_build_array(:'owner', :'f1', :'w1')),
  'the project team joins the chat'
);
select is(
  (select jsonb_agg(jsonb_build_array(m ->> 'senderId', m ->> 'kind', m ->> 'systemEvent') order by m ->> 'subjectUserId')
   from jsonb_array_elements(public.get_messages(:'c1') -> 'messages') m),
  (select jsonb_agg(jsonb_build_array('system', 'system', 'memberAdded')) from generate_series(1, 2)),
  'with a system message for each newcomer'
);

select tests.login_as(:'w2');
select is(public.get_chats(), '[]'::jsonb, 'someone outside the team has no chat');
select is(tests.error_of(format($$ select public.get_messages(%L) $$, :'c1')), 'PT403 forbidden', 'and gets 403 for it');
select is((select count(*)::int from public.messages) + (select count(*)::int from public.chats), 0,
  'and reads nothing from the tables');
select tests.login_as(:'owner_b');
select is(tests.error_of(format($$ select public.get_messages(%L) $$, :'c1')), 'PT404 not_found',
  'another company gets 404');

-- ── Text ─────────────────────────────────────────────────────

select tests.login_as(:'f1');
select gen_random_uuid() as client1 \gset
select public.send_message(:'c1', :'client1', 'text', '  Бетон привезли  ') as m1 \gset
select is(
  :'m1'::jsonb - 'id' - 'createdAt',
  jsonb_build_object('clientId', :'client1', 'chatId', :'c1', 'senderId', :'f1', 'kind', 'text',
    'text', 'Бетон привезли', 'status', 'sent', 'attachments', '[]'::jsonb, 'listened', false,
    'reportId', null, 'systemEvent', null, 'subjectUserId', null),
  'send_message returns the message in the client format'
);
select is(public.send_message(:'c1', :'client1', 'text', 'Бетон привезли') ->> 'id', :'m1'::jsonb ->> 'id',
  'a retry with the same clientId returns the same message');
select is((select count(*)::int from public.messages where client_id = :'client1'), 1, 'and creates no copy');

select is(tests.error_of(format($$ select public.send_message(%L, gen_random_uuid(), 'text', '   ') $$, :'c1')),
  'PT400 invalid_text', 'a blank text is rejected');
select is(tests.error_of(format($$ select public.send_message(%L, gen_random_uuid(), 'text', repeat('я', 4001)) $$, :'c1')),
  'PT400 invalid_text', 'a text over 4000 is rejected');
select is(tests.error_of(format($$ select public.send_message(%L, gen_random_uuid(), 'system', 'x') $$, :'c1')),
  'PT400 invalid_kind', 'clients cannot send system messages');
select is(tests.error_of(format($$ select public.send_message(%L, gen_random_uuid(), 'report', 'x') $$, :'c1')),
  'PT400 invalid_kind', 'nor report cards yet');
select is(tests.error_of(format($$ select public.send_message(%L, %L, 'text', 'x') $$, gen_random_uuid(), :'client1')),
  'PT400 client_id_reused', 'a clientId belongs to one message');

-- ── Unread and read ──────────────────────────────────────────

select tests.login_as(:'owner');
select is(
  (public.get_chats() -> 0) -> 'unreadCount',
  '1'::jsonb,
  'the others have one unread: system messages do not count'
);
select is((public.get_chats() -> 0) -> 'lastMessage' ->> 'id', :'m1'::jsonb ->> 'id', 'lastMessage is the newest');

select tests.login_as(:'f1');
select is((public.get_chats() -> 0) -> 'unreadCount', '0'::jsonb, 'sending marks the chat read for the sender');
select is((public.get_chats() -> 0) -> 'lastMessage' ->> 'status', 'sent', 'nobody has read it yet');

select tests.login_as(:'owner');
select lives_ok(format($$ select public.mark_read(%L, %L) $$, :'c1', :'m1'::jsonb ->> 'id'), 'mark_read');
select is((public.get_chats() -> 0) -> 'unreadCount', '0'::jsonb, 'reading clears the unread count');
select tests.login_as(:'f1');
select is((public.get_chats() -> 0) -> 'lastMessage' ->> 'status', 'read', 'the sender sees it read');

select public.send_message(:'c1', gen_random_uuid(), 'text', 'Второе') ->> 'id' as m2 \gset
select tests.login_as(:'owner');
select public.mark_read(:'c1', :'m2') is null as ok \gset
select public.mark_read(:'c1', (:'m1'::jsonb ->> 'id')::uuid) is null as ok \gset
select is((public.get_chats() -> 0) -> 'unreadCount', '0'::jsonb, 'an older mark does not move the mark back');
select is(tests.error_of(format($$ select public.mark_read(%L, gen_random_uuid()) $$, :'c1')),
  'PT404 not_found', 'an unknown message gives 404');

-- ── Photos and voice ─────────────────────────────────────────

reset role;
select tests.photo(:'f1') as ph1 \gset
select tests.photo(:'f1') as ph2 \gset
select tests.voice(:'f1') as v1 \gset
select tests.photo(:'f1') as ph3 \gset
select tests.login_as(:'f1');

select public.send_message(:'c1', gen_random_uuid(), 'photo', ' Армирование ', array[:'ph2'::uuid, :'ph1'::uuid]) as photo_message \gset
select is(
  (select jsonb_agg(jsonb_build_array(a ->> 'id', a ->> 'width', a ->> 'height', a ->> 'bucket'))
   from jsonb_array_elements(:'photo_message'::jsonb -> 'attachments') a),
  jsonb_build_array(jsonb_build_array(:'ph2', '1600', '1200', 'photos'), jsonb_build_array(:'ph1', '1600', '1200', 'photos')),
  'a photo message keeps the order and the sizes of its photos'
);
select is(:'photo_message'::jsonb ->> 'text', 'Армирование', 'with the caption');

select is(tests.error_of(format($$ select public.send_message(%L, gen_random_uuid(), 'photo', null, '{}') $$, :'c1')),
  'PT400 invalid_attachments', 'a photo message needs a photo');
select is(tests.error_of(format($$ select public.send_message(%L, gen_random_uuid(), 'photo', null, %L) $$, :'c1',
  (select array_agg(gen_random_uuid()) from generate_series(1, 11)))),
  'PT400 invalid_attachments', 'at most 10');
select is(tests.error_of(format($$ select public.send_message(%L, gen_random_uuid(), 'photo', null, array[%L::uuid]) $$, :'c1', :'ph1')),
  'PT403 attachment_forbidden', 'a photo goes into one message only');

select is(tests.error_of(format($$ select public.send_message(%L, gen_random_uuid(), 'voice', 'текст', array[%L::uuid]) $$, :'c1', :'v1')),
  'PT400 invalid_text', 'a voice note has no text');
select is(tests.error_of(format($$ select public.send_message(%L, gen_random_uuid(), 'voice', null, array[%L::uuid]) $$, :'c1', :'ph3')),
  'PT400 wrong_attachment_kind', 'a voice message needs a voice attachment');
select public.send_message(:'c1', gen_random_uuid(), 'voice', null, array[:'v1'::uuid]) as voice_message \gset
select is(
  (:'voice_message'::jsonb -> 'attachments' -> 0) - 'id' - 'path' - 'waveform',
  jsonb_build_object('bucket', 'voice', 'mime', 'audio/mp4', 'durationMs', 42400),
  'a voice message carries its duration'
);
select is(jsonb_array_length(:'voice_message'::jsonb -> 'attachments' -> 0 -> 'waveform'), 40, 'and the waveform');
select :'voice_message'::jsonb ->> 'id' as vm \gset

select tests.login_as(:'w1');
select is(
  (select count(*)::int from storage.objects where name in (
    select path from public.attachments where message_id in (:'vm', (:'photo_message'::jsonb ->> 'id')::uuid))),
  3,
  'chat members may read the files'
);
select is((select (m ->> 'listened')::boolean from jsonb_array_elements(public.get_messages(:'c1') -> 'messages') m
  where m ->> 'id' = :'vm'), false, 'a voice note starts unlistened');
select lives_ok(format($$ select public.mark_listened(%L, %L) $$, :'c1', :'vm'), 'mark_listened');
select lives_ok(format($$ select public.mark_listened(%L, %L) $$, :'c1', :'vm'), 'twice is fine');
select is((select (m ->> 'listened')::boolean from jsonb_array_elements(public.get_messages(:'c1') -> 'messages') m
  where m ->> 'id' = :'vm'), true, 'then it is listened for this user');
select tests.login_as(:'owner');
select is((select (m ->> 'listened')::boolean from jsonb_array_elements(public.get_messages(:'c1') -> 'messages') m
  where m ->> 'id' = :'vm'), false, 'and only for them');
select is(tests.error_of(format($$ select public.mark_listened(%L, %L) $$, :'c1', :'m2')),
  'PT404 not_found', 'a text message cannot be listened');
select tests.login_as(:'f1');
select is(tests.error_of(format($$ select public.mark_listened(%L, %L) $$, :'c1', :'vm')),
  'PT404 not_found', 'nor your own voice note');

select tests.login_as(:'w2');
select is((select count(*)::int from storage.objects), 0, 'outsiders read no files');

-- ── Pages ────────────────────────────────────────────────────

reset role;
insert into public.messages (chat_id, sender_id, kind, text)
select :'c1', :'f1', 'text', 'Сообщение ' || i from generate_series(1, 600) i;
select tests.login_as(:'owner');

select public.get_messages(:'c1') as page \gset
select is(
  jsonb_build_array(jsonb_array_length(:'page'::jsonb -> 'messages'),
    :'page'::jsonb -> 'messages' -> 0 ->> 'text', :'page'::jsonb -> 'messages' -> 49 ->> 'text'),
  jsonb_build_array(50, 'Сообщение 551', 'Сообщение 600'),
  'the last 50 by default, oldest first'
);
select public.get_messages(:'c1', p_before => (:'page'::jsonb -> 'messages' -> 0 ->> 'id')::uuid, p_limit => 3) as older \gset
select is(
  (select jsonb_agg(m ->> 'text') from jsonb_array_elements(:'older'::jsonb -> 'messages') m),
  '["Сообщение 548", "Сообщение 549", "Сообщение 550"]'::jsonb,
  'before= gives the older ones'
);
select public.get_messages(:'c1', p_after => (:'older'::jsonb -> 'messages' -> 2 ->> 'id')::uuid) as newer \gset
select is(
  jsonb_build_array(jsonb_array_length(:'newer'::jsonb -> 'messages'), :'newer'::jsonb -> 'truncated'),
  '[50, false]'::jsonb,
  'after= gives everything newer'
);
select public.get_messages(:'c1', p_after => (:'m1'::jsonb ->> 'id')::uuid) as missed \gset
select is(
  jsonb_build_array(jsonb_array_length(:'missed'::jsonb -> 'messages'), :'missed'::jsonb -> 'truncated',
    :'missed'::jsonb -> 'messages' -> 499 ->> 'text'),
  '[500, true, "Сообщение 600"]'::jsonb,
  'after= with more than 500 missed gives the newest 500 and truncated'
);
select is(tests.error_of(format($$ select public.get_messages(%L, p_limit => 101) $$, :'c1')), 'PT400 invalid_limit', 'limit is 1–100');
select is(tests.error_of(format($$ select public.get_messages(%L, p_before => gen_random_uuid()) $$, :'c1')),
  'PT404 not_found', 'an unknown message gives 404');

-- ── Leaving and coming back ──────────────────────────────────

select public.update_project(:'p1', p_worker_ids => array[]::uuid[]) is not null as ok \gset
select tests.login_as(:'w1');
select is(public.get_chats(), '[]'::jsonb, 'a worker taken off the project loses the chat');
select is(tests.error_of(format($$ select public.send_message(%L, gen_random_uuid(), 'text', 'Я тут') $$, :'c1')),
  'PT403 forbidden', 'and cannot write to it');
select tests.login_as(:'owner');
select is((public.get_messages(:'c1', p_limit => 1) -> 'messages' -> 0) - 'id' - 'clientId' - 'createdAt' - 'chatId',
  jsonb_build_object('senderId', 'system', 'kind', 'system', 'text', null, 'status', 'sent',
    'attachments', '[]'::jsonb, 'listened', false, 'reportId', null,
    'systemEvent', 'memberRemoved', 'subjectUserId', :'w1'),
  'the others get a system message');
select public.update_project(:'p1', p_worker_ids => array[:'w1'::uuid]) is not null as ok \gset
select tests.login_as(:'w1');
select ok((public.get_messages(:'c1', p_before => (:'m2')::uuid) -> 'messages') @> jsonb_build_array(jsonb_build_object('id', :'m1'::jsonb ->> 'id')),
  'put back on the project, they see the whole history');

-- ── Direct chats ─────────────────────────────────────────────

select tests.login_as(:'owner');
select public.get_or_create_direct(:'w1') as direct \gset
select :'direct'::jsonb ->> 'id' as d1 \gset
select is(
  jsonb_build_array(:'direct'::jsonb ->> 'type', :'direct'::jsonb ->> 'title', tests.sorted(:'direct'::jsonb -> 'participantIds')),
  jsonb_build_array('direct', '', tests.sorted(jsonb_build_array(:'owner', :'w1'))),
  'get_or_create_direct creates a direct chat of the two'
);
select tests.login_as(:'w1');
select is(public.get_or_create_direct(:'owner') ->> 'id', :'d1', 'the same chat from the other side');
select is(tests.error_of(format($$ select public.get_or_create_direct(%L) $$, :'w1')), 'PT400 self_chat', 'not with yourself');
select is(tests.error_of(format($$ select public.get_or_create_direct(%L) $$, :'owner_b')), 'PT404 not_found', 'not with another company');

-- ── Removal from the company ─────────────────────────────────

select tests.as_service();
select public.remove_member(:'owner', :'w1') as ok \gset
select tests.login_as(:'owner');
select is(
  (select jsonb_agg(c ->> 'id' order by c ->> 'id') from jsonb_array_elements(public.get_chats()) c),
  (select jsonb_agg(id order by id) from jsonb_array_elements_text(jsonb_build_array(:'c1', :'d1')) id),
  'the direct chat with a removed member stays with the other person'
);
select is(tests.error_of(format($$ select public.send_message(%L, gen_random_uuid(), 'text', 'Привет') $$, :'d1')),
  'PT403 forbidden', 'but is read-only');
select is((public.get_messages(:'c1', p_limit => 1) -> 'messages' -> 0) ->> 'systemEvent', 'memberRemoved',
  'the project chat says the member left');

select * from finish();
rollback;
