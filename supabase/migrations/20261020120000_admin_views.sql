-- =====================================================================
-- Engager: admin member list and locked accounts (Stage 2)
--
-- Needs 20261009120000_classrooms_groups.sql applied first.
--
-- What this does:
--   * Adds two admin-only functions so the admin screens can list the
--     members of a group (name and join date, never email or posts) and
--     the accounts that are locked out of joining right now.
--   * Does not change any table, policy, post or engagement.
--
-- BACK UP THE DATABASE FIRST (pg_dump), same as for the first migration.
--
-- It runs as one transaction: if any statement fails, nothing is changed.
-- To undo: supabase/rollbacks/20261020120000_admin_views_rollback.sql
-- =====================================================================

begin;

do $$
begin
  if to_regclass('public.groups') is null then
    raise exception 'apply 20261009120000_classrooms_groups.sql first';
  end if;
end;
$$;

-- Members of one group, for the admin screens. Name and join date only.
create or replace function public.admin_group_members(p_group_id uuid)
returns table (user_id uuid, full_name text, joined_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  if not public.is_admin() then
    raise exception 'Admin only' using errcode = '42501';
  end if;

  return query
    select gm.user_id, p.full_name, gm.joined_at
    from public.group_members gm
    join public.profiles p on p.id = gm.user_id
    where gm.group_id = p_group_id
    order by p.full_name, gm.joined_at;
end;
$$;

-- Accounts with 5 or more wrong codes in the last 24 hours, which is the
-- same rule join_group uses to refuse them. Name and counts only.
create or replace function public.admin_locked_accounts()
returns table (user_id uuid, full_name text, failed_count bigint, last_failed_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  if not public.is_admin() then
    raise exception 'Admin only' using errcode = '42501';
  end if;

  return query
    select ja.user_id, p.full_name, count(*), max(ja.attempted_at)
    from public.join_attempts ja
    join public.profiles p on p.id = ja.user_id
    where ja.succeeded = false
      and ja.attempted_at > now() - interval '24 hours'
    group by ja.user_id, p.full_name
    having count(*) >= 5
    order by max(ja.attempted_at) desc;
end;
$$;

revoke execute on function public.admin_group_members(uuid) from public, anon;
revoke execute on function public.admin_locked_accounts()   from public, anon;
grant execute on function public.admin_group_members(uuid) to authenticated;
grant execute on function public.admin_locked_accounts()   to authenticated;

commit;
