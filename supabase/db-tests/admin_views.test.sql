-- admin_views.test.sql: checks for the admin member list and locked accounts functions (run 4 of run.sh).
-- Order: stub.sql, ../schema.sql, the groups migration, the admin views migration, then this file.
-- Scenario: Test Dee (admin), Test Eli and Test Fay in group V1, Test Gus in group V2 and locked.
-- All people, emails and links are fake.

\set ON_ERROR_STOP 1
\pset pager off
\pset tuples_only on
\set QUIET 1
\pset format unaligned

\set admin '00000000-0000-4000-8000-0000000000e0'
\set eli   '00000000-0000-4000-8000-0000000000e1'
\set fay   '00000000-0000-4000-8000-0000000000e2'
\set gus   '00000000-0000-4000-8000-0000000000e3'
\set v1    '00000000-0000-4000-8000-00000000b001'
\set v2    '00000000-0000-4000-8000-00000000b002'
\set hal   '00000000-0000-4000-8000-0000000000e4'

\set as_postgres 'reset role; set request.jwt.claim.sub = '''';'
\set as_anon  'reset role; set request.jwt.claim.sub = ''''; set role anon;'
\set as_admin 'reset role; set request.jwt.claim.sub = ''00000000-0000-4000-8000-0000000000e0''; set role authenticated;'
\set as_hal   'reset role; set request.jwt.claim.sub = ''00000000-0000-4000-8000-0000000000e4''; set role authenticated;'
\set as_eli   'reset role; set request.jwt.claim.sub = ''00000000-0000-4000-8000-0000000000e1''; set role authenticated;'

:as_postgres
insert into auth.users (id, email, raw_user_meta_data) values
  (:'admin', 'test-dee@example.test', '{"full_name": "Test Dee"}'),
  (:'eli',   'test-eli@example.test', '{"full_name": "Test Eli"}'),
  (:'fay',   'test-fay@example.test', '{"full_name": "Test Fay"}'),
  (:'gus',   'test-gus@example.test', '{"full_name": "Test Gus"}'),
  (:'hal',   'test-hal@example.test', '{"full_name": "Test Hal"}');
insert into public.admins (user_id) values (:'admin');
insert into public.classrooms (id, name) values ('00000000-0000-4000-8000-00000000c1b5', 'View Classroom');
insert into public.groups (id, classroom_id, name) values
  (:'v1', '00000000-0000-4000-8000-00000000c1b5', 'V1'),
  (:'v2', '00000000-0000-4000-8000-00000000c1b5', 'V2');
insert into public.group_members (group_id, user_id) values
  (:'v1', :'eli'), (:'v1', :'fay'), (:'v2', :'gus');

-- Gus: 5 wrong codes just now. Fay: 4 wrong codes (not locked). Eli: 5 wrong codes, all older than 24 hours.
insert into public.join_attempts (user_id, succeeded) select :'gus', false from generate_series(1, 5);
insert into public.join_attempts (user_id, succeeded) select :'fay', false from generate_series(1, 4);
insert into public.join_attempts (user_id, succeeded, attempted_at)
  select :'eli', false, now() - interval '25 hours' from generate_series(1, 5);

-- 1. admin_group_members
:as_admin
select tests.check_eq('01a admin lists the two members of V1 by name',
  (select string_agg(full_name, ', ' order by full_name) from public.admin_group_members(:'v1')),
  'Test Eli, Test Fay');
select tests.check_eq('01b admin sees only V2 members for V2',
  (select string_agg(full_name, ', ') from public.admin_group_members(:'v2')), 'Test Gus');
select tests.check_eq('01c unknown group gives no rows',
  (select count(*) from public.admin_group_members('00000000-0000-4000-8000-00000000ffff'))::text, '0');
select tests.check_eq('01d result has exactly the columns user_id, full_name, joined_at',
  (select pg_get_function_result(p.oid) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'admin_group_members'),
  'TABLE(user_id uuid, full_name text, joined_at timestamp with time zone)');

-- 2. admin_locked_accounts
select tests.check_eq('02a only Gus is locked (Fay has 4, Eli is past 24 hours)',
  (select string_agg(full_name, ', ') from public.admin_locked_accounts()), 'Test Gus');
select tests.check_eq('02b Gus shows 5 failed attempts',
  (select failed_count::text from public.admin_locked_accounts() where user_id = :'gus'), '5');
select public.admin_clear_join_lock(:'gus') \gset
select tests.check_eq('02c after unlock nobody is locked',
  (select count(*) from public.admin_locked_accounts())::text, '0');
:as_postgres
insert into public.join_attempts (user_id, succeeded) values (:'fay', false);
:as_admin
select tests.check_eq('02d Fay becomes locked at the 5th wrong code',
  (select string_agg(full_name, ', ') from public.admin_locked_accounts()), 'Test Fay');

-- 3. Who may call them
:as_eli
select tests.check_error('03a member cannot list group members (42501)',
  format('select * from public.admin_group_members(%L)', :'v1'), '42501');
select tests.check_error('03b member cannot list locked accounts (42501)',
  'select * from public.admin_locked_accounts()', '42501');
:as_anon
select tests.check_error('03c anon cannot list group members (42501)',
  format('select * from public.admin_group_members(%L)', :'v1'), '42501');
select tests.check_error('03d anon cannot list locked accounts (42501)',
  'select * from public.admin_locked_accounts()', '42501');
:as_postgres
select tests.check('03e execute is granted to authenticated only',
  has_function_privilege('authenticated', 'public.admin_group_members(uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.admin_locked_accounts()', 'execute')
  and not has_function_privilege('anon', 'public.admin_group_members(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.admin_locked_accounts()', 'execute'));

-- 4. Nothing else changed: row counts in the new tables are what the scenario inserted.
select tests.check('04a the functions wrote nothing (group_members 3, admins 1)',
  (select count(*) from public.group_members) = 3 and (select count(*) from public.admins) = 1);

-- 5. The admin screens end to end, using the real join_group (no hand-inserted attempts).
:as_admin
select group_id as v3_id, invite_code as v3_code from public.create_group('00000000-0000-4000-8000-00000000c1b5', 'V3') \gset
select tests.check_eq('05a is_admin is true for the admin', public.is_admin()::text, 'true');
:as_hal
select tests.check_eq('05b is_admin is false for a member-to-be', public.is_admin()::text, 'false');
select tests.check_eq('05c Hal with 4 wrong codes is not yet locked (wrong 1)', public.join_group('WRONG001'), 'invalid_code');
select public.join_group('WRONG002'), public.join_group('WRONG003'), public.join_group('WRONG004');
:as_admin
select tests.check_eq('05d after 4 wrong codes Hal is not in the locked list',
  (select count(*) from public.admin_locked_accounts() where user_id = :'hal')::text, '0');
:as_hal
select tests.check_eq('05e the 5th wrong code is still invalid_code', public.join_group('WRONG005'), 'invalid_code');
:as_admin
select tests.check_eq('05f after the 5th wrong code Hal is in the locked list with 5',
  (select failed_count::text from public.admin_locked_accounts() where user_id = :'hal'), '5');
:as_hal
select tests.check_eq('05g locked Hal is refused even with the correct code', public.join_group(:'v3_code'), 'locked');
:as_admin
select public.admin_clear_join_lock(:'hal') \gset
select tests.check_eq('05h after unlock Hal is gone from the locked list',
  (select count(*) from public.admin_locked_accounts() where user_id = :'hal')::text, '0');
:as_hal
select tests.check_eq('05i after unlock Hal joins with the correct code', public.join_group(:'v3_code'), 'joined');
:as_admin
select tests.check_eq('05j the member list of V3 now shows Hal',
  (select string_agg(full_name, ', ') from public.admin_group_members(:'v3_id')), 'Test Hal');
select public.admin_move_member(:'hal', :'v3_id', :'v2') \gset
select tests.check_eq('05k after a move V3 is empty and V2 lists Gus and Hal',
  (select count(*) from public.admin_group_members(:'v3_id'))::text || ' '
  || (select string_agg(full_name, ', ' order by full_name) from public.admin_group_members(:'v2')),
  '0 Test Gus, Test Hal');
select public.admin_remove_member(:'hal', :'v2') \gset
select tests.check_eq('05l after a remove V2 lists only Gus',
  (select string_agg(full_name, ', ') from public.admin_group_members(:'v2')), 'Test Gus');

-- 6. The admin sees other people's names only through admin_group_members.
select tests.check_eq('06a admin direct read of profiles returns only the admin''s own row',
  (select count(*) from public.profiles)::text, '1');
select tests.check_eq('06b admin sees no posts', (select count(*) from public.posts)::text, '0');

-- Fail the run if any check failed.
:as_postgres
do $$
declare
  failed int := (select count(*) from tests.results where not ok);
begin
  if failed > 0 then
    raise exception '% test(s) failed', failed;
  end if;
end
$$;
