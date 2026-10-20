-- seed_legacy.sql: fake "live" data that exists BEFORE the classrooms/groups migration.
-- Runs as postgres (superuser, so RLS is bypassed, like rows the live app created over time).
-- 3 legacy users (profiles come from the existing handle_new_user trigger), 6 posts on past
-- days and today, 6 engagements between them (never self). The expected counts, per user
-- given/received engagement counts and content hashes are stored in tests.seed_expect.
--
-- Expected: profiles 3, posts 6, engagements 6.
--   given:    A 2, B 2, C 2
--   received: A 3, B 2, C 1

\set ON_ERROR_STOP 1

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000000a1', 'test-a@example.test', '{"full_name": "Test Student A"}'),
  ('00000000-0000-4000-8000-0000000000a2', 'test-b@example.test', '{"full_name": "Test Student B"}'),
  ('00000000-0000-4000-8000-0000000000a3', 'test-c@example.test', '{"full_name": "Test Student C"}');

insert into public.posts (id, user_id, url, post_date) values
  ('00000000-0000-4000-8000-000000000a11', '00000000-0000-4000-8000-0000000000a1', 'https://www.linkedin.com/posts/test-a-1', public.app_today() - 2),
  ('00000000-0000-4000-8000-000000000a12', '00000000-0000-4000-8000-0000000000a1', 'https://www.linkedin.com/posts/test-a-2', public.app_today() - 1),
  ('00000000-0000-4000-8000-000000000a13', '00000000-0000-4000-8000-0000000000a1', 'https://www.linkedin.com/posts/test-a-3', public.app_today()),
  ('00000000-0000-4000-8000-000000000a21', '00000000-0000-4000-8000-0000000000a2', 'https://www.linkedin.com/posts/test-b-1', public.app_today() - 2),
  ('00000000-0000-4000-8000-000000000a22', '00000000-0000-4000-8000-0000000000a2', 'https://www.linkedin.com/posts/test-b-2', public.app_today()),
  ('00000000-0000-4000-8000-000000000a31', '00000000-0000-4000-8000-0000000000a3', 'https://www.linkedin.com/posts/test-c-1', public.app_today() - 1);

insert into public.engagements (id, post_id, user_id) values
  ('00000000-0000-4000-8000-000000000e01', '00000000-0000-4000-8000-000000000a11', '00000000-0000-4000-8000-0000000000a2'),
  ('00000000-0000-4000-8000-000000000e02', '00000000-0000-4000-8000-000000000a11', '00000000-0000-4000-8000-0000000000a3'),
  ('00000000-0000-4000-8000-000000000e03', '00000000-0000-4000-8000-000000000a21', '00000000-0000-4000-8000-0000000000a1'),
  ('00000000-0000-4000-8000-000000000e04', '00000000-0000-4000-8000-000000000a22', '00000000-0000-4000-8000-0000000000a3'),
  ('00000000-0000-4000-8000-000000000e05', '00000000-0000-4000-8000-000000000a31', '00000000-0000-4000-8000-0000000000a1'),
  ('00000000-0000-4000-8000-000000000e06', '00000000-0000-4000-8000-000000000a13', '00000000-0000-4000-8000-0000000000a2');

-- Content hashes (security definer, so they always see every row regardless of RLS).
create or replace function tests.profiles_hash()
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  return (select md5(coalesce(string_agg(id::text || '|' || full_name || '|' || created_at::text, ',' order by id), ''))
          from public.profiles);
end;
$$;

create or replace function tests.posts_hash()
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  return (select md5(coalesce(string_agg(id::text || '|' || user_id::text || '|' || url || '|' || post_date::text
                                         || '|' || created_at::text, ',' order by id), ''))
          from public.posts);
end;
$$;

create or replace function tests.engagements_hash()
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  return (select md5(coalesce(string_agg(id::text || '|' || post_id::text || '|' || user_id::text
                                         || '|' || created_at::text, ',' order by id), ''))
          from public.engagements);
end;
$$;

grant execute on function tests.profiles_hash(), tests.posts_hash(), tests.engagements_hash()
  to anon, authenticated, service_role;

insert into tests.seed_expect (key, num, txt) values
  ('profiles',    (select count(*) from public.profiles),    tests.profiles_hash()),
  ('posts',       (select count(*) from public.posts),       tests.posts_hash()),
  ('engagements', (select count(*) from public.engagements), tests.engagements_hash());

insert into tests.seed_expect (key, num)
select 'given:' || p.id, (select count(*) from public.engagements e where e.user_id = p.id)
from public.profiles p;

insert into tests.seed_expect (key, num)
select 'received:' || p.id,
       (select count(*) from public.engagements e join public.posts po on po.id = e.post_id where po.user_id = p.id)
from public.profiles p;

-- Sanity: the seed itself is what the tests assume.
do $$
begin
  if tests.expect('profiles') <> 3 or tests.expect('posts') <> 6 or tests.expect('engagements') <> 6 then
    raise exception 'seed_legacy: unexpected counts % % %',
      tests.expect('profiles'), tests.expect('posts'), tests.expect('engagements');
  end if;
  if tests.expect('given:00000000-0000-4000-8000-0000000000a1') <> 2
     or tests.expect('received:00000000-0000-4000-8000-0000000000a1') <> 3
     or tests.expect('received:00000000-0000-4000-8000-0000000000a3') <> 1 then
    raise exception 'seed_legacy: unexpected per user engagement counts';
  end if;
  if exists (select 1 from public.engagements e join public.posts p on p.id = e.post_id where p.user_id = e.user_id) then
    raise exception 'seed_legacy: self engagement in seed';
  end if;
  if (select count(*) from public.posts where post_date = public.app_today()) <> 2 then
    raise exception 'seed_legacy: expected 2 posts dated today';
  end if;
end
$$;
