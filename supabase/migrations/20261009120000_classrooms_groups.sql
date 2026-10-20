-- =====================================================================
-- Engager: classrooms and groups (Stage 1, database only)
--
-- What this does:
--   * Adds classrooms, groups, group memberships, invite codes, admin
--     accounts and a log of join attempts (for the wrong code limit).
--   * Changes who can see what: you now see your own posts and the posts,
--     profiles and engagements of people who share a group with you.
--   * Puts EVERY existing user into one group called "Main group" (in the
--     classroom "Tech4Youth cohort"), so nobody's feed changes today.
--   * Does not change any existing profile, post or engagement row.
--
-- BACK UP THE DATABASE FIRST. Supabase: Database > Backups (or run pg_dump).
--
-- It runs as one transaction: if any statement fails, nothing is changed.
-- It refuses to run twice.
--
-- How to run: Supabase Dashboard > SQL Editor > New query, paste this WHOLE
-- file, press Run. The output shows how many users were moved into the
-- Main group and the Main group invite code.
--
-- DEPLOY TOGETHER WITH THE STAGE 2 APP CODE. After this runs, a NEW signup
-- belongs to no group, so they see nothing and cannot post until the join
-- page (/join/<code>) exists in the app.
--
-- Making the admin account (after this migration):
--   1. Sign up a SEPARATE account in the app (not a student account).
--   2. In the SQL editor run (replace the placeholder email):
--        insert into public.admins (user_id)
--        select id from auth.users where email = '<admin email>';
--   3. If that account existed before this migration, it was put into the
--      Main group. Remove it, because admins are never members:
--        delete from public.group_members
--        where user_id = (select id from auth.users where email = '<admin email>');
--
-- To undo: supabase/rollbacks/20261009120000_classrooms_groups_rollback.sql
-- =====================================================================

begin;

-- Running it twice would fail halfway or duplicate the Main group, so stop
-- early with a clear message instead.
do $$
begin
  if to_regclass('public.groups') is not null then
    raise exception 'classrooms/groups migration already applied';
  end if;
end;
$$;

-- gen_random_bytes() for invite codes. Supabase already has this.
create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------

-- Admin accounts. Added by hand in the SQL editor, never from the app.
create table public.admins (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.classrooms (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (char_length(trim(name)) between 1 and 80),
  created_at timestamptz not null default now()
);

-- "on delete restrict": deleting a classroom must not silently wipe its groups.
create table public.groups (
  id           uuid primary key default gen_random_uuid(),
  classroom_id uuid not null references public.classrooms (id) on delete restrict,
  name         text not null check (char_length(trim(name)) between 1 and 80),
  created_at   timestamptz not null default now(),
  unique (classroom_id, name)
);

-- Many to many: one person can be in several groups.
create table public.group_members (
  group_id  uuid not null references public.groups (id) on delete cascade,
  user_id   uuid not null references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

-- The primary key covers lookups by group; this covers "my groups".
create index group_members_user_id_idx on public.group_members (user_id);

-- One live code per group. Crockford base32, 8 characters, so codes are
-- easy to read aloud and impossible to guess.
create table public.group_invites (
  group_id   uuid primary key references public.groups (id) on delete cascade,
  code       text not null unique check (code ~ '^[0-9A-HJKMNP-TV-Z]{8}$'),
  created_at timestamptz not null default now(),
  rotated_at timestamptz
);

-- Every join attempt. Failed ones drive the join lock (5 wrong codes per
-- rolling 24 hours per account).
create table public.join_attempts (
  id           bigint generated always as identity primary key,
  user_id      uuid not null references public.profiles (id) on delete cascade,
  attempted_at timestamptz not null default now(),
  succeeded    boolean not null
);

create index join_attempts_user_id_attempted_at_idx
  on public.join_attempts (user_id, attempted_at);

alter table public.admins        enable row level security;
alter table public.classrooms    enable row level security;
alter table public.groups        enable row level security;
alter table public.group_members enable row level security;
alter table public.group_invites enable row level security;
alter table public.join_attempts enable row level security;

-- Signed-in users may only READ these tables (and RLS limits which rows).
-- Every write goes through the functions below, which check the rules.
revoke all on public.admins, public.classrooms, public.groups,
  public.group_members, public.group_invites, public.join_attempts
  from anon, authenticated;
grant select on public.admins, public.classrooms, public.groups,
  public.group_members, public.group_invites, public.join_attempts
  to authenticated;
revoke all on sequence public.join_attempts_id_seq from anon, authenticated;

-- ---------------------------------------------------------------------
-- Helper functions
-- SECURITY DEFINER so RLS policies can look at group_members without
-- being blocked by group_members' own RLS (and without recursion).
-- search_path is empty so nobody can trick them with a look-alike table.
-- ---------------------------------------------------------------------

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.admins a where a.user_id = auth.uid()
  );
$$;

create or replace function public.my_group_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select gm.group_id from public.group_members gm where gm.user_id = auth.uid();
$$;

-- The core visibility rule. False when nobody is signed in, because
-- auth.uid() is null and matches no membership row.
create or replace function public.shares_group_with(other uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.group_members mine
    join public.group_members theirs on theirs.group_id = mine.group_id
    where mine.user_id = auth.uid()
      and theirs.user_id = other
  );
$$;

-- 32 symbols, so byte % 32 picks each symbol equally often (256 = 8 * 32).
-- Loops on the (very unlikely) chance the code already exists.
create or replace function public.generate_invite_code()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  alphabet constant text := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  raw      bytea;
  result   text;
begin
  loop
    raw := extensions.gen_random_bytes(8);
    result := '';
    for i in 0..7 loop
      result := result || substr(alphabet, (get_byte(raw, i) % 32) + 1, 1);
    end loop;
    exit when not exists (
      select 1 from public.group_invites gi where gi.code = result
    );
  end loop;
  return result;
end;
$$;

-- Forgiving input: lower case, spaces and dashes are fine, and the letters
-- people confuse with digits (O, I, L) are read as 0 and 1.
create or replace function public.normalize_invite_code(input text)
returns text
language sql
immutable
security definer
set search_path = ''
as $$
  select translate(regexp_replace(upper(input), '[^0-9A-Z]', '', 'g'), 'OIL', '011');
$$;

-- ---------------------------------------------------------------------
-- RPC functions (called from the app)
-- ---------------------------------------------------------------------

-- Returns a status word instead of raising for a wrong code, because an
-- exception would roll back the recorded failed attempt.
-- Status words: 'joined', 'already_member', 'invalid_code', 'locked', 'not_allowed'.
create or replace function public.join_group(code text)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  uid        uuid := auth.uid();
  v_group_id uuid;
  v_failed   bigint;
  v_inserted bigint;
begin
  if uid is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;

  -- Admin accounts never join groups.
  if public.is_admin() then
    return 'not_allowed';
  end if;

  -- One join at a time per account, so parallel requests cannot all slip
  -- under the failed attempt count.
  perform pg_advisory_xact_lock(hashtextextended('engager_join:' || uid::text, 0));

  -- Join lock: 5 wrong codes in any rolling 24 hours locks the account,
  -- whether or not it is already in a group. It is checked BEFORE the code
  -- is looked up, so a locked account is refused even with a correct code
  -- and learns nothing about whether any code exists. Locked calls are not
  -- recorded, so the lock lifts 24 hours after the 5th wrong code.
  select count(*) into v_failed
  from public.join_attempts ja
  where ja.user_id = uid
    and ja.succeeded = false
    and ja.attempted_at > now() - interval '24 hours';

  if v_failed >= 5 then
    return 'locked';
  end if;

  select gi.group_id into v_group_id
  from public.group_invites gi
  where gi.code = public.normalize_invite_code(join_group.code);

  if v_group_id is null then
    insert into public.join_attempts (user_id, succeeded) values (uid, false);
    return 'invalid_code';
  end if;

  insert into public.join_attempts (user_id, succeeded) values (uid, true);

  insert into public.group_members (group_id, user_id)
  values (v_group_id, uid)
  on conflict do nothing;
  get diagnostics v_inserted = row_count;

  if v_inserted > 0 then
    return 'joined';
  end if;
  return 'already_member';
end;
$$;

create or replace function public.create_classroom(name text)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Admin only' using errcode = '42501';
  end if;

  insert into public.classrooms (name)
  values (trim(create_classroom.name))
  returning id into v_id;

  return v_id;
end;
$$;

-- The output columns are named group_id and invite_code, so table columns
-- are only used in insert column lists and returning, never bare in a
-- where clause, to avoid clashing with them.
create or replace function public.create_group(p_classroom_id uuid, p_name text)
returns table (group_id uuid, invite_code text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_group_id uuid;
  v_code     text;
begin
  if not public.is_admin() then
    raise exception 'Admin only' using errcode = '42501';
  end if;

  insert into public.groups as g (classroom_id, name)
  values (p_classroom_id, trim(p_name))
  returning g.id into v_group_id;

  v_code := public.generate_invite_code();

  insert into public.group_invites as gi (group_id, code)
  values (v_group_id, v_code);

  return query select v_group_id, v_code;
end;
$$;

-- The old code stops working the moment this commits.
create or replace function public.rotate_invite_code(p_group_id uuid)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_code text;
begin
  if not public.is_admin() then
    raise exception 'Admin only' using errcode = '42501';
  end if;

  v_code := public.generate_invite_code();

  update public.group_invites gi
  set code = v_code, rotated_at = now()
  where gi.group_id = p_group_id;

  if not found then
    raise exception 'Group not found or it has no invite code'
      using errcode = 'P0002';
  end if;

  return v_code;
end;
$$;

-- Admin: unlock one account by deleting its failed join attempts.
-- Successful attempts are kept. Returns how many failed attempts were cleared.
create or replace function public.admin_clear_join_lock(p_user_id uuid)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_cleared integer;
begin
  if not public.is_admin() then
    raise exception 'Admin only' using errcode = '42501';
  end if;

  delete from public.join_attempts ja
  where ja.user_id = p_user_id
    and ja.succeeded = false;
  get diagnostics v_cleared = row_count;

  return v_cleared;
end;
$$;

-- Admin: move a member from one group to another in one step.
-- Only the membership changes. Posts and engagements are never touched.
create or replace function public.admin_move_member(p_user_id uuid, p_from_group uuid, p_to_group uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin only' using errcode = '42501';
  end if;

  -- Admin accounts are never group members.
  if exists (select 1 from public.admins a where a.user_id = p_user_id) then
    raise exception 'Admin accounts cannot be group members' using errcode = '22023';
  end if;

  if p_from_group = p_to_group then
    raise exception 'Source and target group are the same' using errcode = '22023';
  end if;

  if not exists (select 1 from public.groups g where g.id = p_to_group) then
    raise exception 'Target group not found' using errcode = 'P0002';
  end if;

  delete from public.group_members gm
  where gm.user_id = p_user_id
    and gm.group_id = p_from_group;

  if not found then
    raise exception 'That person is not in the source group' using errcode = 'P0002';
  end if;

  insert into public.group_members (group_id, user_id)
  values (p_to_group, p_user_id)
  on conflict do nothing;
end;
$$;

-- Admin: remove a member from one group. Their other groups, posts and
-- engagements stay exactly as they are.
create or replace function public.admin_remove_member(p_user_id uuid, p_group_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin only' using errcode = '42501';
  end if;

  delete from public.group_members gm
  where gm.user_id = p_user_id
    and gm.group_id = p_group_id;

  if not found then
    raise exception 'That person is not in that group' using errcode = 'P0002';
  end if;
end;
$$;

-- Counts only, never names. A definer function rather than a view so the
-- admin can see every group's numbers without being able to read posts.
-- It applies the same "your groups only" rule as RLS by hand.
-- Subselects (not inner joins) so empty groups still show 0.
create or replace function public.group_totals()
returns table (
  group_id         uuid,
  group_name       text,
  classroom_name   text,
  member_count     bigint,
  post_count       bigint,
  engagement_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    g.id,
    g.name,
    c.name,
    (select count(*)
       from public.group_members m
      where m.group_id = g.id),
    (select count(*)
       from public.posts p
       join public.group_members pm
         on pm.user_id = p.user_id and pm.group_id = g.id),
    (select count(*)
       from public.engagements e
       join public.posts p on p.id = e.post_id
       join public.group_members em
         on em.user_id = e.user_id and em.group_id = g.id
       join public.group_members am
         on am.user_id = p.user_id and am.group_id = g.id)
  from public.groups g
  join public.classrooms c on c.id = g.classroom_id
  where public.is_admin()
     or g.id in (select public.my_group_ids())
  order by c.name, g.name;
$$;

-- Supabase grants execute to everyone by default. Take it away, then give
-- signed-in users only what the app calls. The two code helpers stay
-- internal (used only inside the functions above).
revoke execute on function public.is_admin()                        from public, anon;
revoke execute on function public.my_group_ids()                    from public, anon;
revoke execute on function public.shares_group_with(uuid)           from public, anon;
revoke execute on function public.generate_invite_code()            from public, anon, authenticated;
revoke execute on function public.normalize_invite_code(text)       from public, anon, authenticated;
revoke execute on function public.join_group(text)                  from public, anon;
revoke execute on function public.create_classroom(text)            from public, anon;
revoke execute on function public.create_group(uuid, text)          from public, anon;
revoke execute on function public.rotate_invite_code(uuid)          from public, anon;
revoke execute on function public.group_totals()                    from public, anon;
revoke execute on function public.admin_clear_join_lock(uuid)       from public, anon;
revoke execute on function public.admin_move_member(uuid, uuid, uuid) from public, anon;
revoke execute on function public.admin_remove_member(uuid, uuid)   from public, anon;

grant execute on function public.is_admin()               to authenticated;
grant execute on function public.my_group_ids()           to authenticated;
grant execute on function public.shares_group_with(uuid)  to authenticated;
grant execute on function public.join_group(text)         to authenticated;
grant execute on function public.create_classroom(text)   to authenticated;
grant execute on function public.create_group(uuid, text) to authenticated;
grant execute on function public.rotate_invite_code(uuid) to authenticated;
grant execute on function public.group_totals()           to authenticated;
grant execute on function public.admin_clear_join_lock(uuid)         to authenticated;
grant execute on function public.admin_move_member(uuid, uuid, uuid) to authenticated;
grant execute on function public.admin_remove_member(uuid, uuid)     to authenticated;

-- ---------------------------------------------------------------------
-- Row Level Security
-- Old rule: every signed-in user reads everything.
-- New rule: you read your own rows plus those of people in your groups.
-- "Users can insert their own profile" is unchanged.
-- ---------------------------------------------------------------------
drop policy "Signed-in users can read profiles"          on public.profiles;
drop policy "Signed-in users can read posts"             on public.posts;
drop policy "Users can insert their own post for today"  on public.posts;
drop policy "Signed-in users can read engagements"       on public.engagements;
drop policy "Users can insert their own engagements"     on public.engagements;

-- profiles
create policy "Users can read profiles of people in their groups"
  on public.profiles for select to authenticated
  using (id = auth.uid() or public.shares_group_with(id));

-- posts
create policy "Users can read posts from their groups"
  on public.posts for select to authenticated
  using (user_id = auth.uid() or public.shares_group_with(user_id));

-- Posting needs at least one group, otherwise nobody could ever see it.
create policy "Members can insert their own post for today"
  on public.posts for insert to authenticated
  with check (
    user_id = auth.uid()
    and post_date = public.app_today()
    and exists (select 1 from public.my_group_ids())
  );

-- engagements: you see who engaged with YOUR posts, and your own.
create policy "Users can read their own engagements and those on their posts"
  on public.engagements for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.posts p
      where p.id = post_id and p.user_id = auth.uid()
    )
  );

-- You can only engage with posts you are allowed to see.
create policy "Members can engage with posts in their groups"
  on public.engagements for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.posts p
      where p.id = post_id and public.shares_group_with(p.user_id)
    )
  );

-- admins: lets the app ask "am I an admin?" and nothing more.
create policy "Users can read their own admin row"
  on public.admins for select to authenticated
  using (user_id = auth.uid());

create policy "Users can read classrooms of their groups"
  on public.classrooms for select to authenticated
  using (
    public.is_admin()
    or id in (
      select g.classroom_id from public.groups g
      where g.id in (select public.my_group_ids())
    )
  );

create policy "Users can read their own groups"
  on public.groups for select to authenticated
  using (public.is_admin() or id in (select public.my_group_ids()));

-- Only your own memberships, so member lists never leak.
create policy "Users can read their own memberships"
  on public.group_members for select to authenticated
  using (user_id = auth.uid());

-- Codes are shown to the admin only; members get them as a shared link.
create policy "Admins can read invite codes"
  on public.group_invites for select to authenticated
  using (public.is_admin());

-- join_attempts has no policies on purpose: nobody reads it from the app.

-- ---------------------------------------------------------------------
-- Move existing data
-- Everyone who exists today goes into one Main group, so every feed
-- looks exactly the same as before.
-- ---------------------------------------------------------------------
do $$
declare
  v_classroom_id uuid;
  v_group_id     uuid;
  v_code         text;
  v_moved        bigint;
begin
  insert into public.classrooms (name)
  values ('Tech4Youth cohort')
  returning id into v_classroom_id;

  insert into public.groups (classroom_id, name)
  values (v_classroom_id, 'Main group')
  returning id into v_group_id;

  insert into public.group_members (group_id, user_id)
  select v_group_id, p.id from public.profiles p;
  get diagnostics v_moved = row_count;

  v_code := public.generate_invite_code();

  insert into public.group_invites (group_id, code)
  values (v_group_id, v_code);

  raise notice 'Moved % existing users into Main group. Main group invite code: %',
    v_moved, v_code;
end;
$$;

commit;
