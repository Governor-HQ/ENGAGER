-- groups.test.sql: assertions after the classrooms/groups migration (run 1 of run.sh).
-- Order: stub.sql, ../schema.sql, seed_legacy.sql, the migration, then this file.
-- Every check prints one PASS/FAIL line. Users are impersonated the Supabase way (role plus
-- request.jwt.claim.sub), so policies and grants are exercised exactly as through the API.
-- All people, emails and links are fake.

\set ON_ERROR_STOP 1
\pset pager off
\pset tuples_only on
\pset format unaligned

-- Fixed fake ids.
\set l1    '00000000-0000-4000-8000-0000000000a1'
\set l2    '00000000-0000-4000-8000-0000000000a2'
\set l3    '00000000-0000-4000-8000-0000000000a3'
\set admin '00000000-0000-4000-8000-0000000000f0'
\set u1    '00000000-0000-4000-8000-0000000000b1'
\set u2    '00000000-0000-4000-8000-0000000000b2'
\set u3    '00000000-0000-4000-8000-0000000000b3'
\set u4    '00000000-0000-4000-8000-0000000000b4'
\set u5    '00000000-0000-4000-8000-0000000000b5'
\set ur    '00000000-0000-4000-8000-0000000000c1'
\set uf    '00000000-0000-4000-8000-0000000000c2'
\set p_u1  '00000000-0000-4000-8000-000000000b11'
\set p_u2  '00000000-0000-4000-8000-000000000b21'
\set p_u3  '00000000-0000-4000-8000-000000000b31'
\set p_u5  '00000000-0000-4000-8000-000000000b51'
\set p_l1_today '00000000-0000-4000-8000-000000000a13'
\set code_re '^[0-9A-HJKMNP-TV-Z]{8}$'

-- Impersonation shortcuts.
\set as_postgres 'reset role; set request.jwt.claim.sub = '''';'
\set as_anon     'reset role; set request.jwt.claim.sub = ''''; set role anon;'
\set as_nobody   'reset role; set request.jwt.claim.sub = ''''; set role authenticated;'
\set as_l1    'reset role; set request.jwt.claim.sub = ''00000000-0000-4000-8000-0000000000a1''; set role authenticated;'
\set as_l3    'reset role; set request.jwt.claim.sub = ''00000000-0000-4000-8000-0000000000a3''; set role authenticated;'
\set as_admin 'reset role; set request.jwt.claim.sub = ''00000000-0000-4000-8000-0000000000f0''; set role authenticated;'
\set as_u1    'reset role; set request.jwt.claim.sub = ''00000000-0000-4000-8000-0000000000b1''; set role authenticated;'
\set as_u2    'reset role; set request.jwt.claim.sub = ''00000000-0000-4000-8000-0000000000b2''; set role authenticated;'
\set as_u3    'reset role; set request.jwt.claim.sub = ''00000000-0000-4000-8000-0000000000b3''; set role authenticated;'
\set as_u4    'reset role; set request.jwt.claim.sub = ''00000000-0000-4000-8000-0000000000b4''; set role authenticated;'
\set as_u5    'reset role; set request.jwt.claim.sub = ''00000000-0000-4000-8000-0000000000b5''; set role authenticated;'
\set as_ur    'reset role; set request.jwt.claim.sub = ''00000000-0000-4000-8000-0000000000c1''; set role authenticated;'
\set as_uf    'reset role; set request.jwt.claim.sub = ''00000000-0000-4000-8000-0000000000c2''; set role authenticated;'

-- =====================================================================
-- 1-3. Migration of existing data (as postgres)
-- =====================================================================
:as_postgres

select tests.check('01a every legacy profile is a member of Main group in Tech4Youth cohort',
  (select count(*) from public.profiles p
    where exists (select 1 from public.group_members m
                    join public.groups g on g.id = m.group_id
                    join public.classrooms c on c.id = g.classroom_id
                   where m.user_id = p.id and g.name = 'Main group' and c.name = 'Tech4Youth cohort'))
  = tests.expect('profiles'));

select tests.check('01b migration created exactly one classroom, one group and 3 memberships',
  (select count(*) from public.classrooms) = 1
  and (select count(*) from public.groups) = 1
  and (select count(*) from public.group_members) = tests.expect('profiles'));

select tests.check_eq('01c posts rows unchanged from the seed',
  (select count(*) from public.posts)::text || ' ' || tests.posts_hash(),
  tests.expect('posts')::text || ' ' || tests.expect_txt('posts'));

select tests.check_eq('01d engagements rows unchanged from the seed',
  (select count(*) from public.engagements)::text || ' ' || tests.engagements_hash(),
  tests.expect('engagements')::text || ' ' || tests.expect_txt('engagements'));

select tests.check_eq('01e profiles rows unchanged from the seed',
  (select count(*) from public.profiles)::text || ' ' || tests.profiles_hash(),
  tests.expect('profiles')::text || ' ' || tests.expect_txt('profiles'));

select tests.check('01f RLS enabled on all six new tables; join_attempts has no policies',
  (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relrowsecurity
      and c.relname in ('admins', 'classrooms', 'groups', 'group_members', 'group_invites', 'join_attempts')) = 6
  and not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'join_attempts'));

select tests.check('01g old read-all and insert policies are gone, own profile insert policy kept',
  not exists (select 1 from pg_policies where schemaname = 'public' and policyname in (
      'Signed-in users can read profiles', 'Signed-in users can read posts', 'Signed-in users can read engagements',
      'Users can insert their own post for today', 'Users can insert their own engagements'))
  and exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles'
                and policyname = 'Users can insert their own profile'));

-- 2. Legacy users keep their feed.
:as_l1
select tests.check_eq('02a legacy user A still sees every legacy post',
  (select count(*) from public.posts)::text, tests.expect('posts')::text);
select tests.check('02b legacy user A still sees the names of B and C',
  (select count(*) from public.profiles where full_name in ('Test Student B', 'Test Student C')) = 2);
select tests.check_eq('02c legacy user A engagements given unchanged',
  (select count(*) from public.engagements where user_id = auth.uid())::text,
  tests.expect('given:' || :'l1')::text);
select tests.check_eq('02d legacy user A engagements received unchanged',
  (select count(*) from public.engagements e join public.posts p on p.id = e.post_id
    where p.user_id = auth.uid())::text,
  tests.expect('received:' || :'l1')::text);
:as_l3
select tests.check_eq('02e legacy user C feed not empty and complete',
  (select count(*) from public.posts)::text, tests.expect('posts')::text);
select tests.check_eq('02f legacy user C given/received unchanged',
  (select count(*) from public.engagements where user_id = auth.uid())::text || '/'
  || (select count(*) from public.engagements e join public.posts p on p.id = e.post_id
       where p.user_id = auth.uid())::text,
  tests.expect('given:' || :'l3')::text || '/' || tests.expect('received:' || :'l3')::text);

-- 3. Main group invite code.
:as_postgres
select tests.check('03 Main group has one invite code in the 8 char Crockford format',
  (select count(*) from public.group_invites i join public.groups g on g.id = i.group_id
    where g.name = 'Main group' and i.code ~ :'code_re') = 1);

-- =====================================================================
-- Setup: fake users, admin row, classroom and groups G1, G2
-- =====================================================================
:as_postgres
insert into auth.users (id, email, raw_user_meta_data) values
  (:'admin', 'test-admin@example.test', '{"full_name": "Test Admin"}'),
  (:'u1',    'test-u1@example.test',    '{"full_name": "Test Student U1"}'),
  (:'u2',    'test-u2@example.test',    '{"full_name": "Test Student U2"}'),
  (:'u3',    'test-u3@example.test',    '{"full_name": "Test Student U3"}'),
  (:'u4',    'test-u4@example.test',    '{"full_name": "Test Student U4"}'),
  (:'u5',    'test-u5@example.test',    '{"full_name": "Test Student U5"}'),
  (:'ur',    'test-r@example.test',     '{"full_name": "Test Student R"}'),
  (:'uf',    'test-f@example.test',     '{"full_name": "Test Student F"}');
insert into public.admins (user_id) values (:'admin');

select tests.check('S0 new signups are not added to any group automatically',
  not exists (select 1 from public.group_members
               where user_id in (:'admin', :'u1', :'u2', :'u3', :'u4', :'u5', :'ur', :'uf')));

:as_admin
select public.create_classroom('Test Classroom') as cls_id \gset
select group_id as g1_id, invite_code as g1_code from public.create_group(:'cls_id', 'Test Group One') \gset
select group_id as g2_id, invite_code as g2_code from public.create_group(:'cls_id', 'Test Group Two') \gset

select tests.check('S1 admin created classroom and two groups with distinct valid codes',
  :'g1_code' ~ :'code_re' and :'g2_code' ~ :'code_re' and :'g1_code' <> :'g2_code'
  and :'g1_id' <> :'g2_id');

-- =====================================================================
-- 4-7. Joining
-- =====================================================================
:as_u1
select tests.check_eq('04a U1 joins G1 with the exact code', public.join_group(:'g1_code'), 'joined');

:as_u4
select tests.check_eq('04b U4 (no group) with a wrong code gets invalid_code',
  public.join_group('ZZZZZZZZ'), 'invalid_code');

-- Join lock: 5 wrong codes per rolling 24 hours, for every account. User R
-- stays group-less here so U4 keeps its own count; section 20 shows that a
-- member is locked the same way and that other accounts are unaffected.
:as_ur
select tests.check_eq('04c R wrong code 1 of 5 -> invalid_code', public.join_group('WRNGCD01'), 'invalid_code');
select tests.check_eq('04c R wrong code 2 of 5 -> invalid_code', public.join_group('WRNGCD02'), 'invalid_code');
select tests.check_eq('04c R wrong code 3 of 5 -> invalid_code', public.join_group('WRNGCD03'), 'invalid_code');
select tests.check_eq('04c R wrong code 4 of 5 -> invalid_code', public.join_group('WRNGCD04'), 'invalid_code');
select tests.check_eq('04c R wrong code 5 of 5 -> invalid_code', public.join_group('WRNGCD05'), 'invalid_code');
select tests.check_eq('04d R 6th attempt (wrong code) -> locked', public.join_group('WRNGCD06'), 'locked');
select tests.check_eq('04e R correct code while locked -> locked (lock checked before the code)',
  public.join_group(:'g2_code'), 'locked');

:as_postgres
select tests.check_eq('04f locked calls are not recorded (still 5 failures, 0 successes)',
  (select count(*) filter (where not succeeded) || '/' || count(*) filter (where succeeded)
     from public.join_attempts where user_id = :'ur'),
  '5/0');
-- Test clock: age R's failed attempts by 23 hours, still inside the rolling 24.
update public.join_attempts set attempted_at = attempted_at - interval '23 hours' where user_id = :'ur';

:as_ur
select tests.check_eq('04g R 23 hours later: still locked', public.join_group(:'g2_code'), 'locked');

:as_postgres
-- Test clock: one more hour and a minute, so every failure is over 24 hours old.
update public.join_attempts set attempted_at = attempted_at - interval '61 minutes' where user_id = :'ur';

:as_ur
select tests.check_eq('04h R just over 24 hours later: correct code -> joined',
  public.join_group(:'g2_code'), 'joined');

-- 5. Code normalisation: lowercase, spaces, dashes, and 0/1 written as o/l.
:as_u2
select tests.check_eq('05a U2 joins G1 with a lowercase, spaced, dashed, lookalike code (' || v || ')',
  public.join_group(v), 'joined')
from (select ' ' || substr(x, 1, 4) || '-' || substr(x, 5, 4) || ' ' as v
        from (select translate(lower(:'g1_code'), '01', 'ol') as x) a) b;

:as_postgres
select tests.check_eq('05b normalize_invite_code maps case, separators and O/I/L lookalikes',
  public.normalize_invite_code(' ab-cd ef gh o i l '), 'ABCDEFGH011');

:as_u3
select tests.check_eq('05c U3 joins G2', public.join_group(:'g2_code'), 'joined');
:as_u5
select tests.check_eq('05d U5 joins G1', public.join_group(lower(:'g1_code')), 'joined');
select tests.check_eq('05e U5 joins G2 as well (many to many)', public.join_group(:'g2_code'), 'joined');

-- 6. Repeat joins, admin, unsigned callers.
:as_u1
select tests.check_eq('06a U1 joining G1 again -> already_member', public.join_group(:'g1_code'), 'already_member');
:as_admin
select tests.check_eq('06b admin calling join_group with a valid code -> not_allowed',
  public.join_group(:'g1_code'), 'not_allowed');
:as_postgres
select tests.check('06c admin is not a member of any group',
  not exists (select 1 from public.group_members where user_id = :'admin'));
:as_anon
select tests.check_error('06d anon cannot call join_group (42501)',
  format('select public.join_group(%L)', :'g1_code'), '42501');
:as_nobody
select tests.check_error('06e authenticated role without a user id -> 42501 Not signed in',
  format('select public.join_group(%L)', :'g1_code'), '42501');

-- 7. join_attempts bookkeeping and privacy.
:as_postgres
select tests.check_eq('07a join_attempts for R: 5 failures, 1 success',
  (select count(*) filter (where not succeeded) || '/' || count(*) filter (where succeeded)
     from public.join_attempts where user_id = :'ur'),
  '5/1');
select tests.check_eq('07b join_attempts for U4: 1 failure',
  (select count(*) from public.join_attempts where user_id = :'u4' and not succeeded)::text, '1');
select tests.check('07c successful joins are recorded too (U1 has 2 successes: joined, already_member)',
  (select count(*) from public.join_attempts where user_id = :'u1' and succeeded) = 2);
select tests.check('07d admin not_allowed call is not recorded',
  not exists (select 1 from public.join_attempts where user_id = :'admin'));
:as_u1
select tests.check_eq('07e a member selecting join_attempts sees 0 rows',
  tests.count_or_denied('select * from public.join_attempts'), '0');
select tests.check_error('07f a member cannot insert into join_attempts',
  'insert into public.join_attempts (user_id, succeeded) values (auth.uid(), false)', '42501');
select tests.check_error('07g a member cannot delete join_attempts',
  'delete from public.join_attempts', '42501');

-- =====================================================================
-- Isolation setup: posts today by U1, U2 (G1), U3 (G2), U5 (G1 and G2), engagements
-- =====================================================================
:as_u1
select tests.check_ok('S2 U1 posts today (RLS path)',
  format('insert into public.posts (id, user_id, url, post_date) values (%L, auth.uid(), %L, public.app_today())',
         :'p_u1', 'https://www.linkedin.com/posts/test-u1-1'));
:as_u2
select tests.check_ok('S3 U2 posts today (RLS path)',
  format('insert into public.posts (id, user_id, url) values (%L, auth.uid(), %L)',
         :'p_u2', 'https://www.linkedin.com/posts/test-u2-1'));
:as_u3
select tests.check_ok('S4 U3 posts today (RLS path)',
  format('insert into public.posts (id, user_id, url, post_date) values (%L, auth.uid(), %L, public.app_today())',
         :'p_u3', 'https://www.linkedin.com/posts/test-u3-1'));
:as_u5
select tests.check_ok('S5 U5 posts today (RLS path)',
  format('insert into public.posts (id, user_id, url, post_date) values (%L, auth.uid(), %L, public.app_today())',
         :'p_u5', 'https://www.linkedin.com/posts/test-u5-1'));

-- Engagements inside shared groups: U2 on U1 (G1), U5 on U1 (G1), U3 on U5 (G2), U5 on U3 (G2).
:as_u2
select tests.check_ok('S6 U2 engages U1 post (G1)',
  format('insert into public.engagements (post_id, user_id) values (%L, auth.uid())', :'p_u1'));
:as_u5
select tests.check_ok('S7 U5 engages U1 post (G1)',
  format('insert into public.engagements (post_id, user_id) values (%L, auth.uid())', :'p_u1'));
select tests.check_ok('S8 U5 engages U3 post (G2)',
  format('insert into public.engagements (post_id, user_id) values (%L, auth.uid())', :'p_u3'));
:as_u3
select tests.check_ok('S9 U3 engages U5 post (G2)',
  format('insert into public.engagements (post_id, user_id) values (%L, auth.uid())', :'p_u5'));

-- =====================================================================
-- 8-11. Isolation
-- =====================================================================
:as_u1
select tests.check('08a U1 sees U2 post (same group)',
  exists (select 1 from public.posts where id = :'p_u2'));
select tests.check('08b U1 does NOT see U3 post (other group)',
  not exists (select 1 from public.posts where id = :'p_u3'));
select tests.check_eq('08c U1 sees exactly the G1 posts (own, U2, U5), no legacy posts',
  (select count(*) from public.posts)::text, '3');
select tests.check('08d U1 cannot read U3 profile name',
  not exists (select 1 from public.profiles where id = :'u3'));
select tests.check('08e U1 can read U2 profile name',
  exists (select 1 from public.profiles where id = :'u2' and full_name = 'Test Student U2'));
select tests.check('08f U1 cannot read engagements in G2',
  not exists (select 1 from public.engagements where post_id = :'p_u3' or user_id = :'u3'));
select tests.check('08g U1 sees engagements received on own post',
  (select count(*) from public.engagements where post_id = :'p_u1') = 2);
:as_u3
select tests.check('08h U3 sees no posts by G1-only members (U1, U2)',
  not exists (select 1 from public.posts where id in (:'p_u1', :'p_u2')));
select tests.check('08i U3 sees U5 post (shared G2)',
  exists (select 1 from public.posts where id = :'p_u5'));
select tests.check('08j U3 cannot read U1 profile',
  not exists (select 1 from public.profiles where id = :'u1'));
select tests.check('08k U3 sees no legacy posts',
  not exists (select 1 from public.posts where user_id in (:'l1', :'l2', :'l3')));

-- 9. Many to many.
:as_u5
select tests.check_eq('09a U5 (G1 and G2) sees posts from both groups',
  (select string_agg(id::text, ',' order by id) from public.posts),
  (select string_agg(x, ',' order by x) from unnest(array[:'p_u1', :'p_u2', :'p_u3', :'p_u5']) x));
select tests.check('09b U5 sees names of U1 (G1) and U3 (G2)',
  (select count(*) from public.profiles where id in (:'u1', :'u3')) = 2);

-- 10. No group at all.
:as_u4
select tests.check_eq('10a U4 (no group) sees no posts', (select count(*) from public.posts)::text, '0');
select tests.check_eq('10b U4 sees only its own profile',
  (select string_agg(id::text, ',') from public.profiles), :'u4');
select tests.check_eq('10c U4 sees no groups', tests.count_or_denied('select * from public.groups'), '0');
select tests.check_eq('10d U4 sees no classrooms', tests.count_or_denied('select * from public.classrooms'), '0');
select tests.check_eq('10e U4 group_totals returns 0 rows', (select count(*) from public.group_totals())::text, '0');
select tests.check_eq('10f U4 sees no engagements', (select count(*) from public.engagements)::text, '0');
select tests.check_error('10g U4 cannot insert a post (42501)',
  format('insert into public.posts (user_id, url, post_date) values (auth.uid(), %L, public.app_today())',
         'https://www.linkedin.com/posts/test-u4-1'), '42501');

-- 11. Members cannot touch admin objects.
:as_u1
select tests.check_eq('11a member selecting group_invites sees 0 rows',
  tests.count_or_denied('select * from public.group_invites'), '0');
select tests.check_eq('11b member sees only own memberships',
  (select string_agg(user_id::text, ',') from public.group_members), :'u1');
select tests.check_eq('11c member sees only own groups', (select count(*) from public.groups)::text, '1');
select tests.check_eq('11d member sees only the classroom of own groups',
  (select string_agg(name, ',') from public.classrooms), 'Test Classroom');
select tests.check_error('11e member cannot insert into groups',
  format('insert into public.groups (classroom_id, name) values (%L, %L)', :'cls_id', 'Sneaky Group'), '42501');
select tests.check_error('11f member cannot insert into group_members (self join into G2)',
  format('insert into public.group_members (group_id, user_id) values (%L, auth.uid())', :'g2_id'), '42501');
select tests.check_error('11g member cannot insert into classrooms',
  'insert into public.classrooms (name) values (''Sneaky Classroom'')', '42501');
select tests.check_error('11h member cannot insert into group_invites',
  format('insert into public.group_invites (group_id, code) values (%L, %L)', :'g2_id', 'ABCDEFGH'), '42501');
select tests.check_error('11i member cannot update group_invites',
  'update public.group_invites set code = ''ABCDEFGH''', '42501');
select tests.check_error('11j member cannot delete own membership rows directly',
  'delete from public.group_members', '42501');
select tests.check_error('11k member cannot insert into admins',
  'insert into public.admins (user_id) values (auth.uid())', '42501');
select tests.check_error('11l member cannot call create_classroom (42501)',
  'select public.create_classroom(''Sneaky Classroom'')', '42501');
select tests.check_error('11m member cannot call create_group (42501)',
  format('select * from public.create_group(%L, %L)', :'cls_id', 'Sneaky Group'), '42501');
select tests.check_error('11n member cannot call rotate_invite_code (42501)',
  format('select public.rotate_invite_code(%L)', :'g1_id'), '42501');
select tests.check_error('11o member cannot call generate_invite_code (internal only)',
  'select public.generate_invite_code()', '42501');
select tests.check_error('11p member cannot call normalize_invite_code (internal only)',
  'select public.normalize_invite_code(''abc'')', '42501');
:as_postgres
select tests.check('11q execute grants: anon has none of the new functions',
  not has_function_privilege('anon', 'public.join_group(text)', 'execute')
  and not has_function_privilege('anon', 'public.group_totals()', 'execute')
  and not has_function_privilege('anon', 'public.create_classroom(text)', 'execute')
  and not has_function_privilege('anon', 'public.is_admin()', 'execute')
  and not has_function_privilege('anon', 'public.shares_group_with(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.my_group_ids()', 'execute')
  and not has_function_privilege('anon', 'public.rotate_invite_code(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.create_group(uuid, text)', 'execute')
  and not has_function_privilege('anon', 'public.generate_invite_code()', 'execute')
  and not has_function_privilege('anon', 'public.normalize_invite_code(text)', 'execute'));
select tests.check('11r table grants: anon has no privilege, authenticated only select',
  not exists (
    select 1
      from unnest(array['admins', 'classrooms', 'groups', 'group_members', 'group_invites', 'join_attempts']) t,
           unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER']) p
     where has_table_privilege('anon', 'public.' || t, p)
        or (p <> 'SELECT' and p not in ('REFERENCES', 'TRIGGER') and has_table_privilege('authenticated', 'public.' || t, p)))
  and has_table_privilege('authenticated', 'public.groups', 'SELECT'));

-- =====================================================================
-- 12. Counts
-- Memberships now: Main {A, B, C}; G1 {U1, U2, U5}; G2 {U3, U5, R}.
-- G1: 3 members, 3 posts (U1, U2, U5), 2 engagements (U2 on U1, U5 on U1).
-- G2: 3 members, 2 posts (U3, U5), 2 engagements (U3 on U5, U5 on U3).
-- =====================================================================
:as_u1
select tests.check_eq('12a group_totals as U1 returns only G1',
  (select string_agg(group_id::text, ',') from public.group_totals()), :'g1_id');
select tests.check_eq('12b G1 totals as U1: members/posts/engagements',
  (select format('%s/%s/%s', member_count, post_count, engagement_count) from public.group_totals()
    where group_id = :'g1_id'), '3/3/2');
:as_u3
select tests.check_eq('12c group_totals as U3 returns only G2',
  (select string_agg(group_id::text, ',') from public.group_totals()), :'g2_id');
select tests.check_eq('12d G2 totals as U3: members/posts/engagements',
  (select format('%s/%s/%s', member_count, post_count, engagement_count) from public.group_totals()
    where group_id = :'g2_id'), '3/2/2');
:as_u5
select tests.check_eq('12e group_totals as U5 returns exactly G1 and G2',
  (select string_agg(group_name, ',' order by group_name) from public.group_totals()),
  'Test Group One,Test Group Two');
:as_l1
select tests.check_eq('12f group_totals as legacy user A returns only Main group',
  (select string_agg(group_name || '/' || classroom_name, ',') from public.group_totals()),
  'Main group/Tech4Youth cohort');
:as_admin
select tests.check_eq('12g group_totals as admin returns all groups in classroom, group order',
  (select string_agg(group_name, ',' order by n) from public.group_totals() with ordinality as t(a, group_name, b, c, d, e, n)),
  'Main group,Test Group One,Test Group Two');
select tests.check_eq('12h admin sees Main group totals equal to the legacy seed',
  (select format('%s/%s/%s', member_count, post_count, engagement_count) from public.group_totals()
    where group_name = 'Main group'),
  format('%s/%s/%s', tests.expect('profiles'), tests.expect('posts'), tests.expect('engagements')));
select tests.check_eq('12i admin sees G1 and G2 totals',
  (select string_agg(format('%s/%s/%s', member_count, post_count, engagement_count), ',' order by group_name)
     from public.group_totals() where group_id in (:'g1_id', :'g2_id')),
  '3/3/2,3/2/2');
:as_postgres
select tests.check_eq('12j group_totals columns contain no person names',
  (select string_agg(p.parameter_name::text, ',' order by p.ordinal_position)
     from information_schema.parameters p
     join information_schema.routines r
       on r.specific_schema = p.specific_schema and r.specific_name = p.specific_name
    where r.routine_schema = 'public' and r.routine_name = 'group_totals' and p.parameter_mode = 'OUT'),
  'group_id,group_name,classroom_name,member_count,post_count,engagement_count');

-- =====================================================================
-- 13-14. Admin
-- =====================================================================
:as_admin
select tests.check_eq('13a admin sees all groups', (select count(*) from public.groups)::text, '3');
select tests.check_eq('13b admin sees all classrooms',
  (select string_agg(name, ',' order by name) from public.classrooms), 'Tech4Youth cohort,Test Classroom');
select tests.check('13c admin sees all invite codes, all valid',
  (select count(*) from public.group_invites where code ~ :'code_re') = 3
  and exists (select 1 from public.group_invites where group_id = :'g1_id' and code = :'g1_code'));
select public.rotate_invite_code(:'g2_id') as g2_new \gset
select tests.check('13d rotate_invite_code returns a new valid code',
  :'g2_new' ~ :'code_re' and :'g2_new' <> :'g2_code');
select tests.check('13e group_invites holds the new code with rotated_at set',
  exists (select 1 from public.group_invites
           where group_id = :'g2_id' and code = :'g2_new' and rotated_at is not null));
select tests.check_error('13f rotate_invite_code on a missing group raises',
  'select public.rotate_invite_code(''00000000-0000-4000-8000-00000000dead'')', 'any');
:as_uf
select tests.check_eq('13g old G2 code -> invalid_code for a fresh user', public.join_group(:'g2_code'), 'invalid_code');
select tests.check_eq('13h new G2 code -> joined', public.join_group(:'g2_new'), 'joined');

:as_admin
select tests.check_eq('14a admin cannot read posts', (select count(*) from public.posts)::text, '0');
select tests.check_eq('14b admin cannot read engagements', (select count(*) from public.engagements)::text, '0');
select tests.check_eq('14c admin reads only its own profile',
  (select string_agg(id::text, ',') from public.profiles), :'admin');
select tests.check_eq('14d admin sees no memberships', (select count(*) from public.group_members)::text, '0');
select tests.check_error('14e admin cannot post (not a member)',
  format('insert into public.posts (user_id, url) values (auth.uid(), %L)', 'https://www.linkedin.com/posts/test-admin-1'),
  '42501');

-- =====================================================================
-- 15-18. Existing rules still hold
-- =====================================================================
:as_u1
select tests.check_error('15 one post per user per day: U1 second post today -> 23505',
  format('insert into public.posts (user_id, url, post_date) values (auth.uid(), %L, public.app_today())',
         'https://www.linkedin.com/posts/test-u1-2'), '23505');
:as_u2
select tests.check_error('16a post dated yesterday -> denied (42501)',
  format('insert into public.posts (user_id, url, post_date) values (auth.uid(), %L, public.app_today() - 1)',
         'https://www.linkedin.com/posts/test-u2-2'), '42501');
select tests.check_error('16b post dated tomorrow -> denied (42501)',
  format('insert into public.posts (user_id, url, post_date) values (auth.uid(), %L, public.app_today() + 1)',
         'https://www.linkedin.com/posts/test-u2-3'), '42501');
select tests.check_error('16c post for another user -> denied (42501)',
  format('insert into public.posts (user_id, url) values (%L, %L)', :'u4', 'https://www.linkedin.com/posts/test-u2-4'),
  '42501');
:as_u1
select tests.check_error('17 self engagement -> check_violation 23514',
  format('insert into public.engagements (post_id, user_id) values (%L, auth.uid())', :'p_u1'), '23514');
select tests.check_error('18a U1 engaging U3 post (other group) -> denied (42501)',
  format('insert into public.engagements (post_id, user_id) values (%L, auth.uid())', :'p_u3'), '42501');
select tests.check_error('18b U1 engaging a legacy post (not shared) -> denied (42501)',
  format('insert into public.engagements (post_id, user_id) values (%L, auth.uid())', :'p_l1_today'), '42501');
select tests.check_error('18c U1 engaging on behalf of U2 -> denied (42501)',
  format('insert into public.engagements (post_id, user_id) values (%L, %L)', :'p_u5', :'u2'), '42501');
select tests.check_ok('18d U1 engaging U2 post (own group) succeeds',
  format('insert into public.engagements (post_id, user_id) values (%L, auth.uid())', :'p_u2'));
select tests.check_error('18e U1 engaging the same post twice -> 23505',
  format('insert into public.engagements (post_id, user_id) values (%L, auth.uid())', :'p_u2'), '23505');

-- =====================================================================
-- 19. anon sees nothing
-- =====================================================================
:as_anon
select tests.check('19a anon sees no posts',
  tests.count_or_denied('select * from public.posts') in ('0', 'denied'));
select tests.check('19b anon sees no profiles',
  tests.count_or_denied('select * from public.profiles') in ('0', 'denied'));
select tests.check('19c anon sees no engagements',
  tests.count_or_denied('select * from public.engagements') in ('0', 'denied'));
select tests.check('19d anon sees no groups',
  tests.count_or_denied('select * from public.groups') in ('0', 'denied'));
select tests.check('19e anon sees no classrooms, memberships or invites',
  tests.count_or_denied('select * from public.classrooms') in ('0', 'denied')
  and tests.count_or_denied('select * from public.group_members') in ('0', 'denied')
  and tests.count_or_denied('select * from public.group_invites') in ('0', 'denied'));
select tests.check_error('19f anon cannot call group_totals (42501)', 'select * from public.group_totals()', '42501');

-- =====================================================================
-- 20. Join lock for members, admin move, remove and unlock.
-- Runs last because it changes memberships.
-- =====================================================================
-- 20a-e: U3 is a member of G2 and is locked exactly like a group-less account.
:as_u3
select tests.check_eq('20a U3 (a member) wrong code 1 of 5 -> invalid_code', public.join_group('WRNGCD11'), 'invalid_code');
select tests.check_eq('20a U3 (a member) wrong code 2 of 5 -> invalid_code', public.join_group('WRNGCD12'), 'invalid_code');
select tests.check_eq('20a U3 (a member) wrong code 3 of 5 -> invalid_code', public.join_group('WRNGCD13'), 'invalid_code');
select tests.check_eq('20a U3 (a member) wrong code 4 of 5 -> invalid_code', public.join_group('WRNGCD14'), 'invalid_code');
select tests.check_eq('20a U3 (a member) wrong code 5 of 5 -> invalid_code', public.join_group('WRNGCD15'), 'invalid_code');
select tests.check_eq('20b U3 6th attempt -> locked', public.join_group('WRNGCD16'), 'locked');
select tests.check_eq('20c U3 correct G1 code while locked -> locked', public.join_group(:'g1_code'), 'locked');
:as_u4
select tests.check_eq('20d another account (U4) is not locked by U3: wrong code -> invalid_code',
  public.join_group('WRNGCD17'), 'invalid_code');
:as_uf
select tests.check_eq('20e another account (F) still joins with a correct code while U3 is locked',
  public.join_group(:'g1_code'), 'joined');

-- 20f-r: move and remove. Snapshot first.
:as_postgres
select count(*) as u5_posts_before from public.posts where user_id = :'u5' \gset
select count(*) as u5_eng_before from public.engagements where user_id = :'u5' \gset
select count(*) as u2_posts_before from public.posts where user_id = :'u2' \gset
select count(*) as u2_eng_before from public.engagements where user_id = :'u2' \gset
-- What U5 should still see after leaving G2: its own posts and posts by G1 members.
select string_agg(p.id::text, ',' order by p.id) as u5_g1_view
from public.posts p
where p.user_id = :'u5'
   or p.user_id in (select gm.user_id from public.group_members gm where gm.group_id = :'g1_id') \gset

:as_u5
select tests.check('20f before removal U5 sees U3''s post through G2',
  exists (select 1 from public.posts where id = :'p_u3'));

:as_u1
select tests.check_error('20g a member cannot call admin_remove_member (42501)',
  format('select public.admin_remove_member(%L, %L)', :'u5', :'g2_id'), '42501');
select tests.check_error('20h a member cannot call admin_move_member (42501)',
  format('select public.admin_move_member(%L, %L, %L)', :'u2', :'g1_id', :'g2_id'), '42501');
:as_anon
select tests.check_error('20i anon cannot call admin_remove_member (42501)',
  format('select public.admin_remove_member(%L, %L)', :'u5', :'g2_id'), '42501');

:as_admin
select tests.check_ok('20j admin removes U5 from G2',
  format('select public.admin_remove_member(%L, %L)', :'u5', :'g2_id'));
select tests.check_error('20k removing a membership that does not exist raises P0002',
  format('select public.admin_remove_member(%L, %L)', :'u5', :'g2_id'), 'P0002');

:as_postgres
select tests.check_eq('20l U5 is now only in G1',
  (select string_agg(group_id::text, ',') from public.group_members where user_id = :'u5'), :'g1_id');
select tests.check_eq('20m removal kept U5''s posts and engagements',
  (select count(*) from public.posts where user_id = :'u5') || '/' ||
  (select count(*) from public.engagements where user_id = :'u5'),
  :'u5_posts_before' || '/' || :'u5_eng_before');
:as_u5
select tests.check_eq('20n U5 still sees exactly its own and G1 posts (G1 view unchanged)',
  (select string_agg(id::text, ',' order by id) from public.posts), :'u5_g1_view');
select tests.check('20o U5 no longer sees U3''s G2-only post',
  not exists (select 1 from public.posts where id = :'p_u3'));

:as_admin
select tests.check_ok('20p admin moves U2 from G1 to G2',
  format('select public.admin_move_member(%L, %L, %L)', :'u2', :'g1_id', :'g2_id'));
select tests.check_error('20q moving someone who is not in the source group raises P0002',
  format('select public.admin_move_member(%L, %L, %L)', :'u2', :'g1_id', :'g2_id'), 'P0002');
select tests.check_error('20q moving into the same group raises 22023',
  format('select public.admin_move_member(%L, %L, %L)', :'u2', :'g2_id', :'g2_id'), '22023');
select tests.check_error('20q moving into a group that does not exist raises P0002',
  format('select public.admin_move_member(%L, %L, %L)', :'u2', :'g2_id', '00000000-0000-4000-8000-00000000dead'), 'P0002');
select tests.check_error('20q moving the admin account raises 22023 (admins are never members)',
  format('select public.admin_move_member(%L, %L, %L)', :'admin', :'g1_id', :'g2_id'), '22023');

:as_postgres
select tests.check_eq('20r U2 is now only in G2',
  (select string_agg(group_id::text, ',') from public.group_members where user_id = :'u2'), :'g2_id');
select tests.check_eq('20r move kept U2''s posts and engagements',
  (select count(*) from public.posts where user_id = :'u2') || '/' ||
  (select count(*) from public.engagements where user_id = :'u2'),
  :'u2_posts_before' || '/' || :'u2_eng_before');
:as_u2
select tests.check('20r U2 now sees U3''s post (G2) and no longer U1''s (G1 only)',
  exists (select 1 from public.posts where id = :'p_u3')
  and not exists (select 1 from public.posts where id = :'p_u1'));

-- 20s-x: unlocking.
:as_u1
select tests.check_error('20s a member cannot call admin_clear_join_lock (42501)',
  format('select public.admin_clear_join_lock(%L)', :'u3'), '42501');
:as_anon
select tests.check_error('20t anon cannot call admin_clear_join_lock (42501)',
  format('select public.admin_clear_join_lock(%L)', :'u3'), '42501');
:as_admin
select tests.check_eq('20u admin clears U3''s lock: 5 failed attempts removed',
  public.admin_clear_join_lock(:'u3')::text, '5');
:as_u3
select tests.check_eq('20v U3 after unlock: correct G1 code -> joined', public.join_group(:'g1_code'), 'joined');
:as_postgres
select tests.check_eq('20w U3 has 0 failed attempts left and its successful joins are kept',
  (select count(*) filter (where not succeeded) || '/' || count(*) filter (where succeeded)
     from public.join_attempts where user_id = :'u3'),
  '0/2');

:as_admin
select tests.check_eq('20x after all admin actions the admin still reads no posts',
  tests.count_or_denied('select * from public.posts'), '0');
select tests.check_eq('20x admin is still in no group',
  (select count(*)::text from public.group_members where user_id = :'admin'), '0');

-- =====================================================================
-- Final: fail the run if any check failed.
-- =====================================================================
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
