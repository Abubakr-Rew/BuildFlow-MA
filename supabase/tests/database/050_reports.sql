-- Uploads, Storage policies and reports.
begin;
select plan(42);

select tests.new_owner('owner@a.kg', 'Асан', 'А') as owner \gset
select tests.company_of(:'owner') as company \gset
select tests.new_member(:'company', 'foreman', 'f1@a.kg', 'Бакыт Касымов') as f1 \gset
select tests.new_member(:'company', 'foreman', 'f2@a.kg', 'Данияр') as f2 \gset
select tests.new_member(:'company', 'worker', 'w1@a.kg', 'Эрлан') as w1 \gset
select tests.new_member(:'company', 'worker', 'w2@a.kg', 'Азамат') as w2 \gset
select tests.new_owner('owner@b.kg', 'Чужой', 'Б') as owner_b \gset

select tests.login_as(:'owner');
select public.create_project('ЖК «Ала-Тоо»') ->> 'id' as p1 \gset
select public.update_project(:'p1', p_foreman_ids => array[:'f1'::uuid], p_worker_ids => array[:'w1'::uuid]) is not null as ok \gset
reset role;

-- ── create_upload ────────────────────────────────────────────

select tests.login_as(:'f1');
select public.create_upload('image/jpeg', 389120, 1600, 1200) as upload \gset
select is(:'upload'::jsonb ->> 'bucket', 'photos', 'a photo goes to the photos bucket');
select is(:'upload'::jsonb ->> 'path',
  :'company' || '/' || :'f1' || '/' || (:'upload'::jsonb ->> 'attachmentId') || '.jpg',
  'under company/user/attachment.jpg');
select ok((public.create_upload('image/png', 1000, 10, 10) ->> 'path') like '%.png', 'png keeps its extension');
select ok((public.create_upload('image/webp', 1000, 10, 10) ->> 'path') like '%.webp', 'and webp');

select is(tests.error_of($$ select public.create_upload('image/gif', 1000, 10, 10) $$), 'PT400 unsupported_type', 'gif is not accepted');
select is(tests.error_of($$ select public.create_upload('image/jpeg', 10485761, 10, 10) $$), 'PT400 too_large', 'a photo over 10 MB is rejected');
select is(tests.error_of($$ select public.create_upload('image/jpeg', 0, 10, 10) $$), 'PT400 invalid_size', 'an empty file is rejected');
select is(tests.error_of($$ select public.create_upload('image/jpeg', 1000) $$), 'PT400 invalid_dimensions', 'a photo needs its size');

create temp table wave as select array_agg(i % 101) as w from generate_series(1, 40) i;
grant select on wave to authenticated;
select is(
  (select public.create_upload('audio/mp4', 168400, p_duration_ms => 42400, p_waveform => w) ->> 'bucket' from wave),
  'voice', 'a voice note goes to the voice bucket');
select is(tests.error_of($$ select public.create_upload('audio/mp4', 2097153, p_duration_ms => 42400, p_waveform => w) from wave $$),
  'PT400 too_large', 'a voice note over 2 MB is rejected');
select is(tests.error_of($$ select public.create_upload('audio/mp4', 1000, p_duration_ms => 999, p_waveform => w) from wave $$),
  'PT400 invalid_duration', 'a voice note under a second is rejected');
select is(tests.error_of($$ select public.create_upload('audio/mp4', 1000, p_duration_ms => 300001, p_waveform => w) from wave $$),
  'PT400 invalid_duration', 'and over 5 minutes');
select is(tests.error_of($$ select public.create_upload('audio/mp4', 1000, p_duration_ms => 5000, p_waveform => w[1:39]) from wave $$),
  'PT400 invalid_waveform', 'the waveform has exactly 40 bars');
select is(tests.error_of($$ select public.create_upload('audio/mp4', 1000, p_duration_ms => 5000, p_waveform => w[1:39] || 101) from wave $$),
  'PT400 invalid_waveform', 'each 0–100');

reset role;
insert into private.rate_limit_hits (key) select 'upload:' || :'f2' from generate_series(1, 60);
select tests.login_as(:'f2');
select is(tests.error_of($$ select public.create_upload('image/jpeg', 1000, 10, 10) $$), 'PT429 too_many_requests',
  'the 61st upload in a minute gets 429');
reset role;

-- ── Storage policies ─────────────────────────────────────────

select tests.login_as(:'f1');
select public.create_upload('image/jpeg', 1000, 10, 10) ->> 'path' as path \gset
select tests.login_as(:'w1');
select is(tests.error_of(format($$ insert into storage.objects (bucket_id, name) values ('photos', %L) $$, :'path')),
  '42501', 'nobody else can upload to the path of an attachment');
select is(tests.error_of($$ insert into storage.objects (bucket_id, name) values ('photos', 'anything.jpg') $$),
  '42501', 'nor to a path without an attachment');
select tests.login_as(:'f1');
select is(tests.error_of(format($$ insert into storage.objects (bucket_id, name) values ('voice', %L) $$, :'path')),
  '42501', 'the path belongs to its bucket');
select is(tests.error_of(format($$ insert into storage.objects (bucket_id, name) values ('photos', %L) $$, :'path')),
  'ok', 'the uploader uploads to the path of the own attachment');
reset role;

-- ── submit_report ────────────────────────────────────────────

select tests.photo(:'f1') as ph1 \gset
select tests.photo(:'f1') as ph2 \gset

select tests.login_as(:'f1');
select public.submit_report(:'p1', '  Залили фундамент  ', jsonb_build_array(
  jsonb_build_object('attachmentId', :'ph2', 'takenAt', '2026-11-02T08:12:40Z'),
  jsonb_build_object('attachmentId', :'ph1', 'takenAt', null))) as report \gset

select is(
  :'report'::jsonb - 'id' - 'createdAt' - 'photos',
  jsonb_build_object('projectId', :'p1', 'projectName', 'ЖК «Ала-Тоо»', 'authorId', :'f1',
    'authorName', 'Бакыт Касымов', 'text', 'Залили фундамент'),
  'submit_report returns the report in the client format'
);
select is(
  (select jsonb_agg(jsonb_build_array(p ->> 'id', p ->> 'takenAt', p ->> 'bucket'))
   from jsonb_array_elements(:'report'::jsonb -> 'photos') p),
  jsonb_build_array(
    jsonb_build_array(:'ph2', '2026-11-02T08:12:40+00:00', 'photos'),
    jsonb_build_array(:'ph1', null, 'photos')),
  'photos keep their order and capture time'
);
select :'report'::jsonb ->> 'id' as r1 \gset

select is(tests.error_of(format($$ select public.submit_report(%L, 'x', %L) $$, :'p1',
  jsonb_build_array(jsonb_build_object('attachmentId', :'ph1')))),
  'PT403 attachment_forbidden', 'an attached photo cannot be used again');

reset role;
select tests.photo(:'f1') as ph3 \gset
select tests.photo(:'w1') as foreign_photo \gset
select tests.photo(:'f1', false) as not_uploaded \gset
create temp table photos as
select array_agg(jsonb_build_object('attachmentId', tests.photo(:'f1'))) as six from generate_series(1, 6);
grant select on photos to authenticated;
select tests.login_as(:'f1');

select is(tests.error_of(format($$ select public.submit_report(%L, 'x', %L) $$, :'p1',
  jsonb_build_array(jsonb_build_object('attachmentId', :'foreign_photo')))),
  'PT403 attachment_forbidden', 'someone else''s photo is forbidden');
select is(tests.error_of(format($$ select public.submit_report(%L, 'x', %L) $$, :'p1',
  jsonb_build_array(jsonb_build_object('attachmentId', gen_random_uuid())))),
  'PT403 attachment_forbidden', 'an unknown photo is forbidden');
select is(tests.error_of(format($$ select public.submit_report(%L, 'x', %L) $$, :'p1',
  jsonb_build_array(jsonb_build_object('attachmentId', :'not_uploaded')))),
  'PT400 not_uploaded', 'a photo that isn''t uploaded yet is rejected');
select is(tests.error_of(format($$ select public.submit_report(%L, 'x', %L) $$, :'p1',
  jsonb_build_array(jsonb_build_object('attachmentId', :'ph3'), jsonb_build_object('attachmentId', :'ph3')))),
  'PT400 invalid_attachments', 'the same photo twice is rejected');
select is(tests.error_of(format($$ select public.submit_report(%L, 'x', to_jsonb(six)) from photos $$, :'p1')),
  'PT400 too_many_photos', 'more than 5 photos are rejected');
select is(tests.error_of(format($$ select public.submit_report(%L, 'x', %L) $$, :'p1',
  jsonb_build_array(jsonb_build_object('attachmentId', :'ph3', 'takenAt', 'вчера')))),
  'PT400 invalid_photos', 'a malformed capture time is rejected');
select is(
  (select report_id from public.attachments where id = :'ph3'),
  null,
  'a rejected report leaves its photos free'
);
select ok(
  (public.submit_report(:'p1', '', jsonb_build_array(jsonb_build_object('attachmentId', :'ph3'))) -> 'photos') is not null,
  'so they can go into the next report'
);
select is(jsonb_array_length(public.submit_report(:'p1', 'Без фото') -> 'photos'), 0, 'a report may have no photos');

select tests.login_as(:'f2');
select is(tests.error_of(format($$ select public.submit_report(%L, 'x') $$, :'p1')),
  'PT404 not_found', 'a foreman not on the project gets 404');
select tests.login_as(:'owner');
select is(tests.error_of(format($$ select public.submit_report(%L, 'x') $$, :'p1')),
  'PT403 foreman_only', 'owners do not submit reports');
select tests.login_as(:'w1');
select is(tests.error_of(format($$ select public.submit_report(%L, 'x') $$, :'p1')),
  'PT403 foreman_only', 'nor do workers');

-- ── Visibility ───────────────────────────────────────────────

-- One transaction, one now(): make the order explicit.
reset role;
update public.reports set created_at = now() + interval '1 minute' where text = 'Без фото';
select tests.login_as(:'owner');
select is(jsonb_array_length(public.get_reports()), 3, 'the owner sees the reports of the company');
select is(public.get_reports() -> 0 ->> 'text', 'Без фото', 'newest first');

select tests.login_as(:'w1');
select is(public.get_report(:'r1') -> 'photos' -> 0 ->> 'id', :'ph2', 'a worker of the project sees the report and its photos');
select is(
  (select count(*)::int from storage.objects where name in (select path from public.attachments where report_id = :'r1')),
  2,
  'and may read its files in Storage'
);

select tests.login_as(:'w2');
select is(public.get_reports(), '[]'::jsonb, 'a worker of another project sees no reports');
select is(tests.error_of(format($$ select public.get_report(%L) $$, :'r1')), 'PT404 not_found', 'and gets 404 for one');
select is(
  (select count(*)::int from storage.objects) + (select count(*)::int from public.attachments),
  0,
  'and no files or attachments'
);

select tests.login_as(:'owner_b');
select is(
  jsonb_array_length(public.get_reports()) + (select count(*)::int from storage.objects),
  0,
  'another company sees no reports and no files'
);

select * from finish();
rollback;
