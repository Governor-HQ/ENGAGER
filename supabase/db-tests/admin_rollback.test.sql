-- admin_rollback.test.sql: the admin views rollback removes only its two functions (run 6 of run.sh).
-- Order: stub.sql, ../schema.sql, the groups migration, the admin views migration, the admin views
-- rollback, then this file. All people, emails and links are fake.

\set ON_ERROR_STOP 1
\pset pager off
\pset tuples_only on
\set QUIET 1
\pset format unaligned

\set as_postgres 'reset role; set request.jwt.claim.sub = '''';'
:as_postgres

select tests.check('01a admin_group_members is gone',
  to_regprocedure('public.admin_group_members(uuid)') is null);
select tests.check('01b admin_locked_accounts is gone',
  to_regprocedure('public.admin_locked_accounts()') is null);
select tests.check('01c the groups migration is untouched: its tables and functions remain',
  to_regclass('public.groups') is not null
  and to_regclass('public.group_invites') is not null
  and to_regprocedure('public.join_group(text)') is not null
  and to_regprocedure('public.group_totals()') is not null
  and to_regprocedure('public.admin_move_member(uuid,uuid,uuid)') is not null);
select tests.check('01d row level security is still on for groups',
  (select relrowsecurity from pg_class where oid = 'public.groups'::regclass));

do $$
declare
  failed int := (select count(*) from tests.results where not ok);
begin
  if failed > 0 then
    raise exception '% test(s) failed', failed;
  end if;
end
$$;
