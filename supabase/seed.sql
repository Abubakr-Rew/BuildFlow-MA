-- Demo data, as in the Fake repositories: the company «СтройБишкек», six
-- users (password 123456 for all), four projects, reports and chat history.
-- Applied by `supabase db reset`. Photos and voice notes need real files in
-- Storage, so the seed has text only.

-- Registration triggers are deferred to commit; run each one right away.
set constraints all immediate;

-- ── Users ────────────────────────────────────────────────────

create function pg_temp.add_user(p_id uuid, p_email text, p_user_meta jsonb, p_app_meta jsonb)
returns void
language plpgsql
as $$
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    email_change_token_current, phone_change, phone_change_token, reauthentication_token
  ) values (
    '00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated',
    p_email, extensions.crypt('123456', extensions.gen_salt('bf')), now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb || p_app_meta, p_user_meta,
    now() - interval '60 days', now() - interval '60 days',
    '', '', '', '', '', '', '', ''
  );
  insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
  values (
    gen_random_uuid(), p_id, p_id::text, 'email',
    jsonb_build_object('sub', p_id::text, 'email', p_email, 'email_verified', true),
    now(), now(), now()
  );
end;
$$;

-- The owner registers the company; the others join by invite codes, the
-- way the app does it.
select pg_temp.add_user('a0000000-0000-4000-8000-000000000001', 'owner@buildflow.kg',
  '{"name": "Асан Бекович", "company_name": "СтройБишкек"}', '{}');

insert into public.invites (code, company_id, role, created_by)
select codes.code, p.company_id, codes.role::public.user_role, p.id
from public.profiles p,
  (values ('DEMFA2', 'foreman'), ('DEMFB3', 'foreman'),
          ('DEMWA4', 'worker'), ('DEMWB5', 'worker'), ('DEMWC6', 'worker')) as codes (code, role)
where p.email = 'owner@buildflow.kg';

select pg_temp.add_user('a0000000-0000-4000-8000-000000000002', 'foreman1@buildflow.kg',
  '{"name": "Бакыт Касымов"}', '{"invite_code": "DEMFA2"}');
select pg_temp.add_user('a0000000-0000-4000-8000-000000000003', 'foreman2@buildflow.kg',
  '{"name": "Данияр Жумабеков"}', '{"invite_code": "DEMFB3"}');
select pg_temp.add_user('a0000000-0000-4000-8000-000000000004', 'worker1@buildflow.kg',
  '{"name": "Эрлан Токтосунов"}', '{"invite_code": "DEMWA4"}');
select pg_temp.add_user('a0000000-0000-4000-8000-000000000005', 'worker2@buildflow.kg',
  '{"name": "Нурлан Абдыраев"}', '{"invite_code": "DEMWB5"}');
select pg_temp.add_user('a0000000-0000-4000-8000-000000000006', 'worker3@buildflow.kg',
  '{"name": "Азамат Асанов"}', '{"invite_code": "DEMWC6"}');

-- ── Projects ─────────────────────────────────────────────────

insert into public.projects (id, company_id, name, address, status, progress, created_at)
select demo.id::uuid, p.company_id, demo.name, demo.address, demo.status::public.project_status,
  demo.progress, now() - interval '60 days'
from public.profiles p,
  (values
    ('b0000000-0000-4000-8000-000000000001', 'ЖК «Ала-Тоо Резиденс»', 'ул. Токтогула 125, Бишкек', 'active', 65),
    ('b0000000-0000-4000-8000-000000000002', 'Коттеджный посёлок «Горный»', 'с. Кок-Жар, Чуйская обл.', 'active', 30),
    ('b0000000-0000-4000-8000-000000000003', 'Офис «Байтик»', 'пр. Чуй 55А, Бишкек', 'paused', 45),
    ('b0000000-0000-4000-8000-000000000004', 'Склад на Дэн Сяопина', 'ул. Дэн Сяопина 200, Бишкек', 'finished', 100)
  ) as demo (id, name, address, status, progress)
where p.email = 'owner@buildflow.kg';

insert into public.project_members (project_id, user_id) values
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002'),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000004'),
  ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000002'),
  ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000003'),
  ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000004'),
  ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000005'),
  ('b0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000003'),
  ('b0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000005'),
  ('b0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000006');

-- The demo starts with the teams in place, not with «joined» messages.
delete from public.messages where kind = 'system';

-- ── Reports ──────────────────────────────────────────────────

insert into public.reports (project_id, author_id, text, created_at) values
  ('b0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000003',
   'Штукатурка стен 2-го этажа завершена на 80%. Завтра закончим оставшуюся часть и приступим к потолкам.',
   now() - interval '2 days 4 hours'),
  ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000002',
   'Завезли пиломатериал для стропильной системы дома №3. Брус 150×200, доска 50×150. Разгрузка и складирование завершены.',
   now() - interval '1 day 6 hours'),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002',
   'Установили арматурный каркас для колонн 2-го этажа. Диаметр 16мм, шаг 200мм. Готовы к заливке.',
   now() - interval '1 day 2 hours'),
  ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000003',
   'Закончили кладку стен 1-го этажа дома №5. Использовали кирпич 250×120×65. Завтра начнём перемычки.',
   now() - interval '5 hours'),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002',
   'Залили фундамент блока Б. Бетон марки М300, всего 42 кубометра. Опалубку снимем через 3 дня.',
   now() - interval '3 hours');

-- ── Chats ────────────────────────────────────────────────────

-- Direct chats: owner ↔ Бакыт, Бакыт ↔ Эрлан.
insert into public.chats (id, company_id, type, direct_key, created_at)
select demo.id::uuid, p.company_id, 'direct', demo.direct_key, now() - interval '30 days'
from public.profiles p,
  (values
    ('c0000000-0000-4000-8000-000000000001',
     'a0000000-0000-4000-8000-000000000001:a0000000-0000-4000-8000-000000000002'),
    ('c0000000-0000-4000-8000-000000000002',
     'a0000000-0000-4000-8000-000000000002:a0000000-0000-4000-8000-000000000004')
  ) as demo (id, direct_key)
where p.email = 'owner@buildflow.kg';

insert into public.chat_members (chat_id, user_id) values
  ('c0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001'),
  ('c0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002'),
  ('c0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000002'),
  ('c0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000004');

-- Messages in time order, so seq follows createdAt. [p_at] is either
-- minutes ago, or a day back and a Bishkek time of day.
create function pg_temp.at(p_days_ago int, p_time time)
returns timestamptz
language sql
as $$
  select ((date_trunc('day', now() at time zone 'Asia/Bishkek') - make_interval(days => p_days_ago) + p_time)
    at time zone 'Asia/Bishkek')
$$;

create function pg_temp.ago(p_minutes int)
returns timestamptz
language sql
as $$
  select now() - make_interval(mins => p_minutes)
$$;

create temp table demo_messages (chat text, sender text, text text, at timestamptz);

-- «Ала-Тоо Резиденс»: four days of history, cycled from the Fake demo lines
-- (fake_chat_demo_data.dart), then today: 66 messages.
with lines (n, sender, text) as (values
  (0, 'f1', 'Доброе утро. Бетон на перекрытие заказал на 9:00, миксеры уже выехали.'),
  (1, 'w1', 'На месте, начинаем.'),
  (2, 'f1', 'Эрлан, проверь вязку на оси Б, там шаг больше 200.'),
  (3, 'w1', 'Шаг поправили, всё по 200.'),
  (4, 'f1', 'Арматуру приняли, технадзор подписал акт.'),
  (5, 'owner', 'Принято. Фото по перекрытию жду до вечера.'),
  (6, 'w1', 'Миксер приехал, начинаем заливку.'),
  (7, 'f1', 'Кран с 13:00 до 14:00 стоит, плановое ТО.'),
  (8, 'w1', 'Генератор опять глохнет, нужен механик.'),
  (9, 'owner', 'Механик будет после обеда, я договорился.'),
  (10, 'f1', 'Не хватает 40 мешков клея для газоблока, закажите, пожалуйста.'),
  (11, 'owner', 'Клей заказал, привезут завтра до обеда.'),
  (12, 'w1', 'Леса на южной стороне закрепили.'),
  (13, 'owner', 'Бакыт, что с поставкой окон?'),
  (14, 'f1', 'Окна обещали в пятницу, звонил поставщику.'),
  (15, 'f1', 'Залили 18 кубов, остался один миксер.'),
  (16, 'w1', 'Закончили на сегодня, инструмент убрали в бытовку.'),
  (17, 'owner', 'Молодцы, идём по графику.')
)
insert into demo_messages
select 'p1', l.sender, l.text, pg_temp.at(day, time '08:05' + make_interval(mins => i * 17))
from generate_series(4, 1, -1) day
cross join generate_series(0, 14) i
join lines l on l.n = (day * 5 + i) % 18
order by day desc, i;

insert into demo_messages values
  ('p1', 'f1', 'Доброе утро. Бетон на 8-й этаж заказал на 9:00.', pg_temp.ago(130)),
  ('p1', 'w1', 'Миксер приехал, начинаем заливку.', pg_temp.ago(118)),
  ('p1', 'w1', 'Второй вибратор взяли из бытовки.', pg_temp.ago(116)),
  ('p1', 'f1', 'Залили 12 кубов из 20, перерыв на обед.', pg_temp.ago(60)),
  ('p1', 'owner', 'Принято. Фото после заливки добавьте в отчёт.', pg_temp.ago(45)),
  ('p1', 'f1', 'Хорошо, к 17:00 будет отчёт.', pg_temp.ago(20)),

  ('p2', 'f2', 'По коттеджу №4 залили фундамент.', pg_temp.at(1, '16:40')),
  ('p2', 'w2', 'Нужна ещё одна бетономешалка, одна не справляется.', pg_temp.at(1, '16:52')),
  ('p2', 'owner', 'Арендуем, завтра будет.', pg_temp.at(1, '17:05')),
  ('p2', 'f2', 'Бетономешалку привезли, спасибо.', pg_temp.ago(90)),
  ('p2', 'f1', 'Кровельщики выходят на №2 в понедельник.', pg_temp.ago(40)),
  ('p2', 'w2', 'Дорогу к участку размыло, грузовик не проходит. Нужен щебень.', pg_temp.ago(15)),

  ('p3', 'owner', 'Ставим объект на паузу до согласования проекта с арендатором.', pg_temp.at(3, '10:15')),
  ('p3', 'f2', 'Понял. Технику вывожу в «Горный».', pg_temp.at(3, '10:32')),
  ('p3', 'w3', 'А нам куда выходить?', pg_temp.at(3, '11:02')),
  ('p3', 'f2', 'Азамат, с понедельника в «Горный», Нурлан покажет.', pg_temp.at(3, '11:10')),

  ('p4', 'owner', 'Объект сдан, акт подписан. Всем спасибо!', pg_temp.at(14, '15:00')),

  ('owner-f1', 'owner', 'Бакыт, завтра в 10 приедет заказчик на «Ала-Тоо», встретишь?', pg_temp.at(1, '18:10')),
  ('owner-f1', 'f1', 'Да, встречу. Подготовлю журнал работ.', pg_temp.at(1, '18:25')),
  ('owner-f1', 'f1', 'Заказчик доволен, просит ускорить фасад.', pg_temp.ago(10)),

  ('f1-w1', 'f1', 'Эрлан, возьми с собой нивелир.', pg_temp.ago(180)),
  ('f1-w1', 'w1', 'Взял.', pg_temp.ago(175));

insert into public.messages (chat_id, sender_id, kind, text, created_at)
select
  case d.chat
    when 'owner-f1' then 'c0000000-0000-4000-8000-000000000001'::uuid
    when 'f1-w1' then 'c0000000-0000-4000-8000-000000000002'::uuid
    else (select c.id from public.chats c
          where c.project_id = ('b0000000-0000-4000-8000-00000000000' || right(d.chat, 1))::uuid)
  end,
  case d.sender
    when 'owner' then 'a0000000-0000-4000-8000-000000000001'::uuid
    when 'f1' then 'a0000000-0000-4000-8000-000000000002'::uuid
    when 'f2' then 'a0000000-0000-4000-8000-000000000003'::uuid
    when 'w1' then 'a0000000-0000-4000-8000-000000000004'::uuid
    when 'w2' then 'a0000000-0000-4000-8000-000000000005'::uuid
    when 'w3' then 'a0000000-0000-4000-8000-000000000006'::uuid
  end,
  'text', d.text, d.at
from demo_messages d
order by d.at;

-- Everyone has read everything except the last N messages from others:
-- Эрлан 2 in «Ала-Тоо», the owner 2 in «Горный» and 1 from Бакыт, Бакыт 1
-- in «Горный» — 3 unread for the owner, as in the Fake demo.
update public.chat_members cm
set last_read_seq = coalesce(
  (select m.seq - 1 from (
     select seq, row_number() over (order by seq desc) as n
     from public.messages
     where chat_id = cm.chat_id and sender_id is distinct from cm.user_id and kind <> 'system'
   ) m where m.n = unread.n),
  (select max(seq) from public.messages where chat_id = cm.chat_id))
from (
  select cm2.chat_id, cm2.user_id,
    case
      when c.project_id = 'b0000000-0000-4000-8000-000000000001'
        and cm2.user_id = 'a0000000-0000-4000-8000-000000000004' then 2
      when c.project_id = 'b0000000-0000-4000-8000-000000000002'
        and cm2.user_id = 'a0000000-0000-4000-8000-000000000001' then 2
      when c.project_id = 'b0000000-0000-4000-8000-000000000002'
        and cm2.user_id = 'a0000000-0000-4000-8000-000000000002' then 1
      when c.id = 'c0000000-0000-4000-8000-000000000001'
        and cm2.user_id = 'a0000000-0000-4000-8000-000000000001' then 1
      else 0
    end as n
  from public.chat_members cm2
  join public.chats c on c.id = cm2.chat_id
) unread
where unread.chat_id = cm.chat_id and unread.user_id = cm.user_id;
