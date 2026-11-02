-- Team: invite codes, joining by code, member search, removal, rate limits.

-- ── Rate limits ──────────────────────────────────────────────

create table private.rate_limit_hits (
  key text not null,
  hit_at timestamptz not null default now()
);

create index rate_limit_hits_key_idx on private.rate_limit_hits (key, hit_at);
create index rate_limit_hits_hit_at_idx on private.rate_limit_hits (hit_at);

-- Counts a request under [p_key]: true if it fits in [p_max] per [p_window],
-- false (and not counted) if it doesn't. Rolled back with the transaction,
-- so a request that fails later doesn't count.
create function private.hit_rate_limit(p_key text, p_max int, p_window interval)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtext('rate_limit:' || p_key));
  delete from private.rate_limit_hits where hit_at < now() - interval '1 day';
  if (
    select count(*) from private.rate_limit_hits
    where key = p_key and hit_at > now() - p_window
  ) >= p_max then
    return false;
  end if;
  insert into private.rate_limit_hits (key) values (p_key);
  return true;
end;
$$;

revoke execute on function private.hit_rate_limit(text, int, interval) from public, anon, authenticated;

-- ── Service functions ────────────────────────────────────────

-- The first statement of every function that only Edge Functions call.
create function private.require_service()
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    perform private.fail(403, 'service_only');
  end if;
end;
$$;

revoke execute on function private.require_service() from public, anon, authenticated;
grant execute on function private.require_service() to service_role;

-- ── Invites ──────────────────────────────────────────────────

-- Alphabet without look-alikes (0/O, 1/I/L): inviteCodeAlphabet in the client.
create table public.invites (
  code text primary key check (code ~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$'),
  company_id uuid not null references public.companies (id),
  role public.user_role not null check (role in ('foreman', 'worker')),
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  used_at timestamptz,
  used_by uuid references auth.users (id) on delete set null
);

create index invites_company_id_idx on public.invites (company_id);

alter table public.invites enable row level security;
revoke all on public.invites from anon, authenticated;
grant select on public.invites to authenticated;

create policy "owners see the company's invites" on public.invites
  for select to authenticated
  using (company_id = private.company_id() and private.user_role() = 'owner');

-- As normalizeInviteCode() in the client: upper case, no spaces or dashes.
create function private.normalize_invite_code(p_code text)
returns text
language sql
immutable
set search_path = ''
as $$
  select upper(regexp_replace(coalesce(p_code, ''), '[[:space:]-]', '', 'g'))
$$;

revoke execute on function private.normalize_invite_code(text) from public, anon, authenticated;

-- Spends the code in one statement: of two concurrent sign-ups with the same
-- code only one gets the row. Unknown, used or expired → 404, which aborts
-- the sign-up, so the user isn't created and the code stays unspent.
create or replace function private.redeem_invite(p_code text, p_user_id uuid)
returns table (out_company_id uuid, out_role public.user_role)
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.invites i
  set used_at = now(), used_by = p_user_id
  where i.code = private.normalize_invite_code(p_code)
    and i.used_at is null
    and i.expires_at > now()
  returning i.company_id, i.role into out_company_id, out_role;

  if not found then
    perform private.fail(404, 'invalid_invite_code');
  end if;
  return next;
end;
$$;

-- `InviteCode` of the client.
create function private.invite_json(i public.invites)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'code', i.code,
    'companyId', i.company_id,
    'role', i.role,
    'createdAt', i.created_at,
    'expiresAt', i.expires_at,
    'isUsed', i.used_at is not null
  )
$$;

revoke execute on function private.invite_json(public.invites) from public, anon, authenticated;

-- POST /team/invite: a one-time code for a foreman or a worker, 7 days.
create function public.create_invite(p_role text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me public.profiles := private.require_owner();
  c_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_code text;
  v_byte int;
  v_invite public.invites;
begin
  if p_role is null or p_role not in ('foreman', 'worker') then
    perform private.fail(400, 'invalid_role');
  end if;

  loop
    v_code := '';
    while char_length(v_code) < 6 loop
      v_byte := get_byte(extensions.gen_random_bytes(1), 0);
      -- 248 = 8 × 31: dropping the rest keeps every letter equally likely.
      if v_byte < 248 then
        v_code := v_code || substr(c_alphabet, v_byte % 31 + 1, 1);
      end if;
    end loop;

    begin
      insert into public.invites (code, company_id, role, created_by)
      values (v_code, me.company_id, p_role::public.user_role, me.id)
      returning * into v_invite;
      return private.invite_json(v_invite);
    exception when unique_violation then
      -- 31⁶ codes: a collision is rare, try another.
    end;
  end loop;
end;
$$;

-- For Edge Function `join`: whether the code would still be accepted.
create function public.invite_is_redeemable(p_code text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_service();
  return exists (
    select 1 from public.invites i
    where i.code = private.normalize_invite_code(p_code)
      and i.used_at is null
      and i.expires_at > now()
  );
end;
$$;

-- For Edge Function `join`: 10 attempts a minute per IP and per device.
create function public.join_rate_limit(p_ip text, p_device_id text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_service();
  if p_ip is not null and not private.hit_rate_limit('join:ip:' || p_ip, 10, interval '1 minute') then
    return false;
  end if;
  if p_device_id is not null
    and not private.hit_rate_limit('join:device:' || p_device_id, 10, interval '1 minute') then
    return false;
  end if;
  return true;
end;
$$;

-- ── Search ───────────────────────────────────────────────────

-- Lower case with ё = е, ң/ө/ү = н/о/у, й/ы = и, э = е, one character for
-- one: _fold() in lib/features/team/domain/member_search.dart.
create function private.fold_name(p_text text)
returns text
language sql
immutable
set search_path = ''
as $$
  select translate(lower(p_text), 'ёэңөүйы', 'ееноуии')
$$;

-- A lower-case Latin query read as Cyrillic, longest match first:
-- _latinToCyrillic() in member_search.dart.
create function private.latin_to_cyrillic(p_text text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  c_pairs constant text[] := array[
    'shch', 'щ', 'sh', 'ш', 'ch', 'ч', 'zh', 'ж', 'kh', 'х', 'ts', 'ц',
    'ya', 'я', 'yu', 'ю', 'yo', 'ё', 'ye', 'е',
    'a', 'а', 'b', 'б', 'c', 'к', 'd', 'д', 'e', 'е', 'f', 'ф', 'g', 'г', 'h', 'х',
    'i', 'и', 'j', 'ж', 'k', 'к', 'l', 'л', 'm', 'м', 'n', 'н', 'o', 'о', 'ö', 'ө',
    'p', 'п', 'q', 'к', 'r', 'р', 's', 'с', 't', 'т', 'u', 'у', 'ü', 'ү', 'v', 'в',
    'w', 'в', 'x', 'кс', 'y', 'ы', 'z', 'з'
  ];
  v_out text := '';
  v_i int := 1;
  v_len int := char_length(p_text);
  v_k int;
  v_matched boolean;
begin
  while v_i <= v_len loop
    v_matched := false;
    v_k := 1;
    while v_k < array_length(c_pairs, 1) loop
      if substr(p_text, v_i, char_length(c_pairs[v_k])) = c_pairs[v_k] then
        v_out := v_out || c_pairs[v_k + 1];
        v_i := v_i + char_length(c_pairs[v_k]);
        v_matched := true;
        exit;
      end if;
      v_k := v_k + 2;
    end loop;
    if not v_matched then
      v_out := v_out || substr(p_text, v_i, 1);
      v_i := v_i + 1;
    end if;
  end loop;
  return v_out;
end;
$$;

-- matchName() in member_search.dart without the ranges: every word of the
-- query is the start of some word of the name.
create function private.name_matches(p_name text, p_query text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(bool_and(exists (
    select 1
    from regexp_split_to_table(private.fold_name(p_name), '[[:space:]-]+') as w (word)
    where starts_with(w.word, t.token)
  )), true)
  from regexp_split_to_table(
    private.fold_name(private.latin_to_cyrillic(lower(p_query))), '[[:space:]-]+'
  ) as t (token)
  where t.token <> ''
$$;

revoke execute on function private.fold_name(text) from public, anon;
revoke execute on function private.latin_to_cyrillic(text) from public, anon;
revoke execute on function private.name_matches(text, text) from public, anon;
grant execute on function private.fold_name(text) to authenticated;
grant execute on function private.latin_to_cyrillic(text) to authenticated;
grant execute on function private.name_matches(text, text) to authenticated;

-- `Member` of the client. assignedProjectIds: the member's projects that
-- the caller sees (RLS on project_members), so foremen and workers only
-- learn about shared projects.
create function private.member_json(p public.profiles)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p.id,
    'userId', p.id,
    'name', p.name,
    'email', p.email,
    'role', p.role,
    'companyId', p.company_id,
    'assignedProjectIds', coalesce((
      select jsonb_agg(m.project_id order by m.added_at, m.project_id)
      from public.project_members m
      where m.user_id = p.id
    ), '[]'::jsonb)
  )
$$;

revoke execute on function private.member_json(public.profiles) from public, anon;
grant execute on function private.member_json(public.profiles) to authenticated;

-- GET /team/members?query=&role=. Without arguments: the whole team. With a
-- query or a role: a search, at most 50; a query shorter than 2 characters
-- finds nobody. Sorted by name.
create function public.get_members(p_query text default null, p_role text default null)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_query text := btrim(p_query);
  v_search boolean := p_query is not null or p_role is not null;
begin
  perform private.require_user();
  if p_role is not null and p_role not in ('owner', 'foreman', 'worker') then
    perform private.fail(400, 'invalid_role');
  end if;
  if p_query is not null and char_length(v_query) < 2 then
    return '[]'::jsonb;
  end if;

  return coalesce((
    select jsonb_agg(private.member_json(m) order by m.name collate "C", m.id)
    from (
      select * from public.profiles p
      where (p_role is null or p.role = p_role::public.user_role)
        and (v_query is null or private.name_matches(p.name, v_query))
      order by p.name collate "C", p.id
      limit case when v_search then 50 end
    ) m
  ), '[]'::jsonb);
end;
$$;

-- ── Removal ──────────────────────────────────────────────────

-- DELETE /team/members/:id, for Edge Function `remove-member`, which checked
-- the owner's token and passes the owner as [p_actor_id]; after this it bans
-- the user in Auth. Service-only, so the removal can't skip the ban.
--
-- Takes the member off every project (the chat stage adds chats and system
-- messages to this transaction) and sets removed_at. 'removed', or
-- 'already_removed' for a member removed before (the function answers 404
-- and bans again); 404 for anyone else outside the company.
create function public.remove_member(p_actor_id uuid, p_member_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor public.profiles;
  v_member public.profiles;
begin
  perform private.require_service();

  select * into v_actor from public.profiles where id = p_actor_id;
  if not found or v_actor.removed_at is not null or v_actor.role <> 'owner' then
    perform private.fail(403, 'owner_only');
  end if;
  if p_member_id = p_actor_id then
    perform private.fail(400, 'cannot_remove_self');
  end if;

  select * into v_member from public.profiles
  where id = p_member_id and company_id = v_actor.company_id
  for update;
  if not found then
    perform private.fail(404, 'not_found', 'Member not found');
  end if;
  if v_member.removed_at is not null then
    return 'already_removed';
  end if;

  delete from public.project_members where user_id = v_member.id;
  update public.profiles set removed_at = now() where id = v_member.id;
  return 'removed';
end;
$$;

revoke execute on function public.create_invite(text) from public, anon;
revoke execute on function public.get_members(text, text) from public, anon;
revoke execute on function public.invite_is_redeemable(text) from public, anon, authenticated;
revoke execute on function public.join_rate_limit(text, text) from public, anon, authenticated;
revoke execute on function public.remove_member(uuid, uuid) from public, anon, authenticated;
grant execute on function public.create_invite(text) to authenticated;
grant execute on function public.get_members(text, text) to authenticated;
grant execute on function public.invite_is_redeemable(text) to service_role;
grant execute on function public.join_rate_limit(text, text) to service_role;
grant execute on function public.remove_member(uuid, uuid) to service_role;

-- ── Registration at commit ───────────────────────────────────

-- Auth's admin.createUser (Edge Function `join`) inserts the user without
-- app metadata and writes it with a second statement of the same
-- transaction, so a plain AFTER INSERT trigger never sees `invite_code`.
-- A deferred constraint trigger runs at commit and reads the row as it is
-- by then; its exception still rolls the whole sign-up back.
drop trigger on_auth_user_created on auth.users;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user auth.users;
  v_name text;
  v_company_name text;
  v_invite_code text;
  v_company uuid;
  v_role public.user_role;
begin
  select * into v_user from auth.users where id = new.id;
  if not found or exists (select 1 from public.profiles where id = new.id) then
    return null;
  end if;

  v_name := nullif(btrim(v_user.raw_user_meta_data ->> 'name'), '');
  v_company_name := nullif(btrim(v_user.raw_user_meta_data ->> 'company_name'), '');
  v_invite_code := v_user.raw_app_meta_data ->> 'invite_code';

  if v_name is null then
    perform private.fail(400, 'name_required');
  end if;

  if v_invite_code is not null then
    select r.out_company_id, r.out_role into v_company, v_role
    from private.redeem_invite(v_invite_code, v_user.id) r;
  elsif v_company_name is not null then
    insert into public.companies (name) values (v_company_name)
    returning id into v_company;
    v_role := 'owner';
  else
    perform private.fail(400, 'company_name_required');
  end if;

  insert into public.profiles (id, company_id, name, email, role)
  values (v_user.id, v_company, v_name, lower(v_user.email), v_role);
  return null;
end;
$$;

create constraint trigger on_auth_user_created
  after insert on auth.users
  deferrable initially deferred
  for each row execute function private.handle_new_user();
