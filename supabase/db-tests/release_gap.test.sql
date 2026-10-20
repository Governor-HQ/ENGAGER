-- release_gap.test.sql: what the CURRENTLY DEPLOYED app (before Stage 2 ships) sees right after the
-- groups migration is applied (run 5 of run.sh).
-- Order: stub.sql, ../schema.sql, seed_legacy.sql, the groups migration, then this file.
-- It runs the same query shapes as app/dashboard/page.js and app/dashboard/actions.js on main,
-- as an existing user and as a brand new signup, through the same role and JWT impersonation as
-- the other suites. It tests the database side only, not the Next.js app.
-- All people, emails and links are fake.

\set ON_ERROR_STOP 1
\pset pager off
\pset tuples_only on
\set QUIET 1
\pset format unaligned

\set ua   '00000000-0000-4000-8000-0000000000a1'
\set uc   '00000000-0000-4000-8000-0000000000a3'
\set newu '00000000-0000-4000-8000-0000000000d9'
\set old_post '00000000-0000-4000-8000-000000000a21'

\set as_postgres 'reset role; set request.jwt.claim.sub = '''';'
\set as_ua  'reset role; set request.jwt.claim.sub = ''00000000-0000-4000-8000-0000000000a1''; set role authenticated;'
\set as_uc  'reset role; set request.jwt.claim.sub = ''00000000-0000-4000-8000-0000000000a3''; set role authenticated;'
\set as_new 'reset role; set request.jwt.claim.sub = ''00000000-0000-4000-8000-0000000000d9''; set role authenticated;'

:as_postgres
select code as main_code from public.group_invites \gset
-- The new signup arrives after the migration: the handle_new_user trigger makes the profile.
insert into auth.users (id, email, raw_user_meta_data)
values (:'newu', 'test-new@example.test', '{"full_name": "Test New Signup"}');

-- 1. An existing user, as the old dashboard queries run.
:as_ua
select tests.check_eq('01a old feed query (others'' posts with author name): same 3 posts as before',
  (select count(*) from public.posts p join public.profiles pr on pr.id = p.user_id where p.user_id <> :'ua')::text, '3');
select tests.check_eq('01b old feed shows every author name (profiles readable)',
  (select count(*) from public.posts p join public.profiles pr on pr.id = p.user_id
    where p.user_id <> :'ua' and pr.full_name is not null)::text, '3');
select tests.check_eq('01c old own profile read works',
  (select full_name from public.profiles where id = :'ua'), 'Test Student A');
select tests.check_eq('01d old "my engagements" read: still 2 given',
  (select count(*) from public.engagements where user_id = :'ua')::text, '2');
select tests.check_eq('01e old "engagements received" count: still 3',
  (select count(*) from public.engagements e join public.posts p on p.id = e.post_id where p.user_id = :'ua')::text, '3');
select tests.check_eq('01f old "my post count" still 3',
  (select count(*) from public.posts where user_id = :'ua')::text, '3');
select tests.check_ok('01g an existing user can still engage with a classmate''s post (old insert)',
  format('insert into public.engagements (post_id, user_id) values (%L, %L)', '00000000-0000-4000-8000-000000000a22', :'ua'));
:as_uc
select tests.check_ok('01h an existing user can still submit today''s post (old insert)',
  format('insert into public.posts (user_id, url) values (%L, %L)', :'uc', 'https://www.linkedin.com/posts/test-c-today'));

-- 2. A brand new signup in the gap.
:as_new
select tests.check_eq('02a new signup has a profile row (sign up itself still works)',
  (select count(*) from public.profiles where id = :'newu')::text, '1');
select tests.check_eq('02b new signup sees no classmate posts',
  (select count(*) from public.posts where user_id <> :'newu')::text, '0');
select tests.check_eq('02c new signup sees no classmate profiles',
  (select count(*) from public.profiles where id <> :'newu')::text, '0');
select tests.check_error('02d new signup cannot post (42501)',
  format('insert into public.posts (user_id, url) values (%L, %L)', :'newu', 'https://www.linkedin.com/posts/test-new-1'), '42501');
select tests.check_error('02e new signup cannot engage with an old post (42501)',
  format('insert into public.engagements (post_id, user_id) values (%L, %L)', :'old_post', :'newu'), '42501');

-- 3. The way out: joining by code makes everything visible and postable.
select tests.check_eq('03a join_group with the Main group code returns joined',
  (select public.join_group(:'main_code')), 'joined');
select tests.check_eq('03b after joining the new signup sees the classmates'' posts',
  (select count(*) from public.posts where user_id <> :'newu')::text, '7');
select tests.check_ok('03c after joining the new signup can post',
  format('insert into public.posts (user_id, url) values (%L, %L)', :'newu', 'https://www.linkedin.com/posts/test-new-2'));

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
