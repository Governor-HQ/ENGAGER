-- propagation.test.sql: one engagement, several shared groups (run 3 of run.sh).
-- Order: stub.sql, ../schema.sql, the migration, then this file (no legacy seed, so the
-- numbers below come only from this scenario).
-- Scenario: Test Ana and Test Ben share groups P1, P2 and P3. Test Cara is only in P1.
-- Ana posts once. Ben engages once. Then Ben is removed from P2, then from every group.
-- All people, emails and links are fake.

\set ON_ERROR_STOP 1
\pset pager off
\pset tuples_only on
\set QUIET 1
\pset format unaligned

\set ana  '00000000-0000-4000-8000-0000000000d1'
\set ben  '00000000-0000-4000-8000-0000000000d2'
\set cara '00000000-0000-4000-8000-0000000000d3'
\set post '00000000-0000-4000-8000-000000000d11'
\set post2 '00000000-0000-4000-8000-000000000d12'

\set as_postgres 'reset role; set request.jwt.claim.sub = '''';'
\set as_ana  'reset role; set request.jwt.claim.sub = ''00000000-0000-4000-8000-0000000000d1''; set role authenticated;'
\set as_ben  'reset role; set request.jwt.claim.sub = ''00000000-0000-4000-8000-0000000000d2''; set role authenticated;'
\set as_cara 'reset role; set request.jwt.claim.sub = ''00000000-0000-4000-8000-0000000000d3''; set role authenticated;'

-- ---------------------------------------------------------------------
-- Setup as postgres: three fake people, one classroom, three groups.
-- (Joining by code is covered in groups.test.sql; here memberships are set directly.)
-- ---------------------------------------------------------------------
:as_postgres
insert into auth.users (id, email, raw_user_meta_data) values
  (:'ana',  'test-ana@example.test',  '{"full_name": "Test Ana"}'),
  (:'ben',  'test-ben@example.test',  '{"full_name": "Test Ben"}'),
  (:'cara', 'test-cara@example.test', '{"full_name": "Test Cara"}');

insert into public.classrooms (id, name) values ('00000000-0000-4000-8000-00000000c1a5', 'Prop Classroom');
insert into public.groups (id, classroom_id, name) values
  ('00000000-0000-4000-8000-00000000a001', '00000000-0000-4000-8000-00000000c1a5', 'P1'),
  ('00000000-0000-4000-8000-00000000a002', '00000000-0000-4000-8000-00000000c1a5', 'P2'),
  ('00000000-0000-4000-8000-00000000a003', '00000000-0000-4000-8000-00000000c1a5', 'P3');
insert into public.group_members (group_id, user_id) values
  ('00000000-0000-4000-8000-00000000a001', :'ana'), ('00000000-0000-4000-8000-00000000a001', :'ben'),
  ('00000000-0000-4000-8000-00000000a002', :'ana'), ('00000000-0000-4000-8000-00000000a002', :'ben'),
  ('00000000-0000-4000-8000-00000000a003', :'ana'), ('00000000-0000-4000-8000-00000000a003', :'ben'),
  ('00000000-0000-4000-8000-00000000a001', :'cara');

-- Ana posts and Ben engages, both through the real RLS path.
:as_ana
select tests.check_ok('PS1 Ana posts today',
  format('insert into public.posts (id, user_id, url) values (%L, %L, %L)',
    :'post', :'ana', 'https://www.linkedin.com/posts/test-ana-1'));
:as_ben
select tests.check_ok('PS2 Ben engages with Ana''s post once',
  format('insert into public.engagements (post_id, user_id) values (%L, %L)', :'post', :'ben'));

-- ---------------------------------------------------------------------
-- a) One row, engaged whichever group Ben looks at.
-- ---------------------------------------------------------------------
:as_postgres
select tests.check_eq('A2a-1 exactly one engagement row exists for Ben on the post',
  (select count(*)::text from public.engagements where post_id = :'post' and user_id = :'ben'), '1');
select tests.check('A2a-2 engagements has no group column, so engaged state cannot differ per group',
  not exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'engagements' and column_name like '%group%'));
:as_ben
select tests.check_eq('A2a-3 Ben''s engaged lookup (what the dashboard asks) returns the row',
  (select count(*)::text from public.engagements where post_id = :'post' and user_id = :'ben'), '1');
:as_postgres
select tests.check_eq('A2a-4 in every group Ben shares with Ana, the post counts as engaged by Ben',
  (select string_agg(g.name || '=' || case when e.id is null then 'no' else 'yes' end, ',' order by g.name)
     from public.groups g
     join public.group_members mb on mb.group_id = g.id and mb.user_id = :'ben'
     join public.group_members ma on ma.group_id = g.id and ma.user_id = :'ana'
     left join public.engagements e on e.post_id = :'post' and e.user_id = :'ben'),
  'P1=yes,P2=yes,P3=yes');

-- ---------------------------------------------------------------------
-- b) group_totals counts it in P1, P2 and P3.
-- ---------------------------------------------------------------------
:as_ben
select tests.check_eq('A2b-1 Ben''s totals: the one post and one engagement count in P1, P2 and P3',
  (select string_agg(group_name || ':' || post_count || '/' || engagement_count, ',' order by group_name)
     from public.group_totals()),
  'P1:1/1,P2:1/1,P3:1/1');
:as_ana
select tests.check_eq('A2b-2 Ana sees the same totals for the same groups',
  (select string_agg(group_name || ':' || post_count || '/' || engagement_count, ',' order by group_name)
     from public.group_totals()),
  'P1:1/1,P2:1/1,P3:1/1');

-- ---------------------------------------------------------------------
-- c) The post appears once in Ben's feed, not three times.
-- ---------------------------------------------------------------------
:as_ben
select tests.check_eq('A2c-1 Ben''s feed query returns Ana''s post exactly once',
  (select count(*)::text from public.posts where user_id <> :'ben'), '1');
select tests.check_eq('A2c-2 the feed as the dashboard asks for it (with author name) is one row',
  (select count(*)::text from public.posts p join public.profiles pr on pr.id = p.user_id
    where p.user_id <> :'ben'), '1');

-- ---------------------------------------------------------------------
-- d) Someone only in P1 sees P1 counts only.
-- ---------------------------------------------------------------------
:as_cara
select tests.check_eq('A2d-1 Cara (P1 only) sees only P1 totals',
  (select string_agg(group_name || ':' || member_count || '/' || post_count || '/' || engagement_count, ','
                     order by group_name) from public.group_totals()),
  'P1:3/1/1');
select tests.check_eq('A2d-2 Cara sees only the P1 group row',
  (select string_agg(name, ',' order by name) from public.groups), 'P1');

-- ---------------------------------------------------------------------
-- e) Ben leaves P2 (removed as postgres, like the admin will in Stage 2).
-- ---------------------------------------------------------------------
:as_postgres
delete from public.group_members
 where group_id = '00000000-0000-4000-8000-00000000a002' and user_id = :'ben';
select tests.check_eq('A2e-1 the engagement row still stands after Ben leaves P2',
  (select count(*)::text from public.engagements where post_id = :'post' and user_id = :'ben'), '1');
:as_ana
select tests.check_eq('A2e-2 Ana''s totals: P2 no longer counts it, P1 and P3 still do',
  (select string_agg(group_name || ':' || post_count || '/' || engagement_count, ',' order by group_name)
     from public.group_totals()),
  'P1:1/1,P2:1/0,P3:1/1');
:as_ben
select tests.check_eq('A2e-3 Ben''s totals now list only P1 and P3, both counting it',
  (select string_agg(group_name || ':' || post_count || '/' || engagement_count, ',' order by group_name)
     from public.group_totals()),
  'P1:1/1,P3:1/1');
select tests.check_eq('A2e-4 Ben still sees the post once and still shows as engaged',
  (select count(*)::text from public.posts p
     join public.engagements e on e.post_id = p.id and e.user_id = :'ben'
    where p.id = :'post'), '1');

-- ---------------------------------------------------------------------
-- f) Ben and Ana share no group any more.
-- ---------------------------------------------------------------------
:as_postgres
delete from public.group_members where user_id = :'ben';
-- A second post by Ana (yesterday, inserted as postgres because Ana already posted today).
insert into public.posts (id, user_id, url, post_date)
values (:'post2', :'ana', 'https://www.linkedin.com/posts/test-ana-2', public.app_today() - 1);
:as_ben
select tests.check_eq('A2f-1 Ben no longer sees any of Ana''s posts',
  (select count(*)::text from public.posts where user_id = :'ana'), '0');
select tests.check_error('A2f-2 Ben cannot engage Ana''s new post (42501)',
  format('insert into public.engagements (post_id, user_id) values (%L, %L)', :'post2', :'ben'), '42501');
select tests.check_eq('A2f-3 Ben still sees his own past engagement row (history kept)',
  (select count(*)::text from public.engagements where user_id = :'ben'), '1');
select tests.check_eq('A2f-4 Ben sees no group totals',
  (select count(*)::text from public.group_totals()), '0');
:as_ana
select tests.check_eq('A2f-5 Ana''s totals no longer count Ben''s engagement anywhere',
  (select string_agg(group_name || ':' || engagement_count, ',' order by group_name)
     from public.group_totals()),
  'P1:0,P2:0,P3:0');

-- ---------------------------------------------------------------------
-- Final: fail the run if any check failed.
-- ---------------------------------------------------------------------
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
