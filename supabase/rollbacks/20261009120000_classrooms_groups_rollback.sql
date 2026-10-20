-- =====================================================================
-- Engager: UNDO classrooms and groups
-- (reverses supabase/migrations/20261009120000_classrooms_groups.sql)
--
-- What this does:
--   * Puts back the original "every signed-in user reads everything"
--     rules from schema.sql.
--   * DELETES all classrooms, groups, memberships, invite codes, admin
--     rows and join attempts, and the functions that used them.
--   * Posts, engagements and profiles are untouched.
--
-- BACK UP THE DATABASE FIRST. Supabase: Database > Backups (or run pg_dump).
-- The deleted group data cannot be recovered without a backup.
--
-- It runs as one transaction: if any statement fails, nothing is changed.
--
-- How to run: Supabase Dashboard > SQL Editor > New query, paste this WHOLE
-- file, press Run. Roll back the Stage 2 app code at the same time, since
-- it expects the group tables and functions to exist.
--
-- This file lives outside supabase/migrations on purpose, so the Supabase
-- CLI never applies it by accident.
-- =====================================================================

begin;

-- Nothing to undo if the migration never ran.
do $$
begin
  if to_regclass('public.groups') is null then
    raise exception 'nothing to roll back';
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- Policies on the original tables: drop the group based ones and
-- recreate the originals exactly as in schema.sql.
-- ---------------------------------------------------------------------
drop policy "Users can read profiles of people in their groups"              on public.profiles;
drop policy "Users can read posts from their groups"                         on public.posts;
drop policy "Members can insert their own post for today"                    on public.posts;
drop policy "Users can read their own engagements and those on their posts" on public.engagements;
drop policy "Members can engage with posts in their groups"                  on public.engagements;

-- profiles ("Users can insert their own profile" was never changed)
create policy "Signed-in users can read profiles"
  on public.profiles for select to authenticated
  using (true);

-- posts
create policy "Signed-in users can read posts"
  on public.posts for select to authenticated
  using (true);

create policy "Users can insert their own post for today"
  on public.posts for insert to authenticated
  with check (user_id = auth.uid() and post_date = public.app_today());

-- engagements
create policy "Signed-in users can read engagements"
  on public.engagements for select to authenticated
  using (true);

create policy "Users can insert their own engagements"
  on public.engagements for insert to authenticated
  with check (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- Policies on the new tables call is_admin() and my_group_ids(), so they
-- must go before those functions can be dropped.
-- ---------------------------------------------------------------------
drop policy "Users can read their own admin row"         on public.admins;
drop policy "Users can read classrooms of their groups"  on public.classrooms;
drop policy "Users can read their own groups"            on public.groups;
drop policy "Users can read their own memberships"       on public.group_members;
drop policy "Admins can read invite codes"               on public.group_invites;

-- ---------------------------------------------------------------------
-- Functions (callers first, helpers last)
-- ---------------------------------------------------------------------
drop function public.admin_remove_member(uuid, uuid);
drop function public.admin_move_member(uuid, uuid, uuid);
drop function public.admin_clear_join_lock(uuid);
drop function public.group_totals();
drop function public.rotate_invite_code(uuid);
drop function public.create_group(uuid, text);
drop function public.create_classroom(text);
drop function public.join_group(text);
drop function public.normalize_invite_code(text);
drop function public.generate_invite_code();
drop function public.shares_group_with(uuid);
drop function public.my_group_ids();
drop function public.is_admin();

-- ---------------------------------------------------------------------
-- Tables, children before parents. pgcrypto stays: Supabase uses it too.
-- ---------------------------------------------------------------------
drop table public.join_attempts;
drop table public.group_invites;
drop table public.group_members;
drop table public.groups;
drop table public.classrooms;
drop table public.admins;

commit;
