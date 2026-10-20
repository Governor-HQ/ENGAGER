-- =====================================================================
-- Engager: UNDO the admin member list and locked accounts functions
-- (reverses supabase/migrations/20261020120000_admin_views.sql)
--
-- Drops the two admin-only functions. No table or data is touched.
-- Run this BEFORE the classrooms/groups rollback, if you use both.
-- It runs as one transaction. It lives outside supabase/migrations on
-- purpose, so the Supabase CLI never applies it by accident.
-- =====================================================================

begin;

drop function public.admin_group_members(uuid);
drop function public.admin_locked_accounts();

commit;
