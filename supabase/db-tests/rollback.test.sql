-- rollback.test.sql: assertions after the migration AND its rollback (run 2 of run.sh).
-- Order: stub.sql, ../schema.sql, seed_legacy.sql, the migration, the rollback, then this file.
-- Checks that every new object is gone, the original five policies from schema.sql are back,
-- posts/engagements/profiles equal the legacy seed, and a legacy user again sees every post.

\set ON_ERROR_STOP 1
\pset pager off
\pset tuples_only on
\pset format unaligned

\set l1 '00000000-0000-4000-8000-0000000000a1'
\set as_postgres 'reset role; set request.jwt.claim.sub = '''';'
\set as_anon     'reset role; set request.jwt.claim.sub = ''''; set role anon;'
\set as_l1 'reset role; set request.jwt.claim.sub = ''00000000-0000-4000-8000-0000000000a1''; set role authenticated;'
\set as_l3 'reset role; set request.jwt.claim.sub = ''00000000-0000-4000-8000-0000000000a3''; set role authenticated;'

:as_postgres

select tests.check_eq('R01 the six new tables are gone',
  (select count(*) from unnest(array['admins', 'classrooms', 'groups', 'group_members', 'group_invites', 'join_attempts']) t
    where to_regclass('public.' || t) is not null)::text,
  '0');

select tests.check_eq('R02 the new functions are gone',
  coalesce((select string_agg(p.proname, ',' order by p.proname)
              from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'public'
               and p.proname in ('is_admin', 'my_group_ids', 'shares_group_with', 'generate_invite_code',
                                 'normalize_invite_code', 'join_group', 'create_classroom', 'create_group',
                                 'rotate_invite_code', 'group_totals', 'admin_clear_join_lock',
                                 'admin_move_member', 'admin_remove_member')), 'none'),
  'none');

select tests.check_eq('R03 exactly the original six policies exist on profiles, posts, engagements',
  (select string_agg(tablename || ':' || cmd || ':' || policyname, ' | ' order by tablename, policyname)
     from pg_policies where schemaname = 'public'),
  'engagements:SELECT:Signed-in users can read engagements | '
  || 'engagements:INSERT:Users can insert their own engagements | '
  || 'posts:SELECT:Signed-in users can read posts | '
  || 'posts:INSERT:Users can insert their own post for today | '
  || 'profiles:SELECT:Signed-in users can read profiles | '
  || 'profiles:INSERT:Users can insert their own profile');

select tests.check('R04 restored policies are to authenticated, read policies use (true)',
  (select bool_and(roles = '{authenticated}'::name[]) from pg_policies where schemaname = 'public')
  and (select bool_and(qual = 'true') from pg_policies where schemaname = 'public' and cmd = 'SELECT'));

select tests.check('R05 restored insert policies have the original checks',
  (select with_check from pg_policies where schemaname = 'public' and policyname = 'Users can insert their own post for today')
    ~ 'user_id = auth\.uid\(\)'
  and (select with_check from pg_policies where schemaname = 'public' and policyname = 'Users can insert their own post for today')
    ~ 'post_date = app_today\(\)'
  and (select with_check from pg_policies where schemaname = 'public' and policyname = 'Users can insert their own post for today')
    !~ 'my_group_ids'
  and (select with_check from pg_policies where schemaname = 'public' and policyname = 'Users can insert their own engagements')
    = '(user_id = auth.uid())');

select tests.check('R06 RLS still enabled on profiles, posts, engagements',
  (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relrowsecurity and c.relname in ('profiles', 'posts', 'engagements')) = 3);

select tests.check('R07 pgcrypto is still installed',
  exists (select 1 from pg_extension where extname = 'pgcrypto'));

select tests.check_eq('R08 posts equal the seed',
  (select count(*) from public.posts)::text || ' ' || tests.posts_hash(),
  tests.expect('posts')::text || ' ' || tests.expect_txt('posts'));
select tests.check_eq('R09 engagements equal the seed',
  (select count(*) from public.engagements)::text || ' ' || tests.engagements_hash(),
  tests.expect('engagements')::text || ' ' || tests.expect_txt('engagements'));
select tests.check_eq('R10 profiles equal the seed',
  (select count(*) from public.profiles)::text || ' ' || tests.profiles_hash(),
  tests.expect('profiles')::text || ' ' || tests.expect_txt('profiles'));

:as_l1
select tests.check_eq('R11 legacy user A again sees every post',
  (select count(*) from public.posts)::text, tests.expect('posts')::text);
select tests.check_eq('R12 legacy user A again sees every profile and engagement',
  (select count(*) from public.profiles)::text || '/' || (select count(*) from public.engagements)::text,
  tests.expect('profiles')::text || '/' || tests.expect('engagements')::text);

-- Original write rules work again without any group (these add rows, so they run after the count checks).
:as_l3
select tests.check_ok('R13 legacy user C (no post today) can post today again',
  format('insert into public.posts (user_id, url, post_date) values (auth.uid(), %L, public.app_today())',
         'https://www.linkedin.com/posts/test-c-2'));
select tests.check_error('R14 one post per day still enforced (23505)',
  format('insert into public.posts (user_id, url, post_date) values (auth.uid(), %L, public.app_today())',
         'https://www.linkedin.com/posts/test-c-3'), '23505');
select tests.check_error('R15 post for another day still denied (42501)',
  format('insert into public.posts (user_id, url, post_date) values (auth.uid(), %L, public.app_today() - 3)',
         'https://www.linkedin.com/posts/test-c-4'), '42501');
select tests.check_error('R16 self engagement still blocked (23514)',
  'insert into public.engagements (post_id, user_id) values (''00000000-0000-4000-8000-000000000a31'', auth.uid())',
  '23514');

:as_anon
select tests.check('R17 anon still sees no posts or profiles',
  tests.count_or_denied('select * from public.posts') in ('0', 'denied')
  and tests.count_or_denied('select * from public.profiles') in ('0', 'denied'));

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
