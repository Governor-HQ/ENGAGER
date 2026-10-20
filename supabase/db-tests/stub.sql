-- stub.sql: local stand-in for the parts of Supabase that schema.sql and the migration rely on.
-- Creates the anon, authenticated and service_role roles, the auth schema (auth.users, auth.uid()),
-- the extensions schema with pgcrypto, Supabase style grants (so RLS is the real barrier, as in
-- production) and the tests schema with the result helpers used by the test files.
-- Only ever run against the throwaway local cluster created by run.sh.

\set ON_ERROR_STOP 1

-- Roles are cluster wide, so create them only once (run 2 reuses the same cluster).
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end
$$;

-- auth schema: just enough of Supabase Auth for the trigger and the policies.
create schema if not exists auth;

create table auth.users (
  id                 uuid primary key default gen_random_uuid(),
  email              text,
  raw_user_meta_data jsonb default '{}'::jsonb
);

create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

-- extensions schema with pgcrypto, as on Supabase.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

grant usage on schema public, auth, extensions to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;

-- Like Supabase: everything postgres creates in public is granted to the API roles.
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public grant execute on functions to anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- tests schema: result recording helpers usable while impersonating.
-- ---------------------------------------------------------------------
create schema tests;

create table tests.results (
  n      serial primary key,
  name   text not null,
  ok     boolean not null,
  detail text
);

create table tests.seed_expect (
  key text primary key,
  num bigint,
  txt text
);

-- Records one result and returns a printable PASS/FAIL line.
create or replace function tests.check(p_name text, p_ok boolean, p_detail text default null)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  passed boolean := coalesce(p_ok, false);
begin
  insert into tests.results (name, ok, detail) values (p_name, passed, p_detail);
  if passed then
    return 'PASS  ' || p_name;
  end if;
  return 'FAIL  ' || p_name
    || coalesce('  [' || p_detail || ']', '')
    || case when p_ok is null then '  [condition was null]' else '' end;
end;
$$;

-- Equality check with a readable detail on failure.
create or replace function tests.check_eq(p_name text, got text, want text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
  return tests.check(p_name, got is not distinct from want,
    format('got %s, want %s', coalesce(got, 'NULL'), coalesce(want, 'NULL')));
end;
$$;

-- Runs sql as the CURRENT role (security invoker) and checks the SQLSTATE it raises.
-- want_state: a SQLSTATE such as 42501, 'no error' for success, or 'any' for any error.
-- On an error the statement is rolled back (subtransaction); on success its effects stay.
create or replace function tests.check_error(p_name text, sql text, want_state text)
returns text
language plpgsql
security invoker
set search_path = ''
as $$
declare
  st  text := 'no error';
  msg text := '';
begin
  begin
    execute sql;
  exception when others then
    get stacked diagnostics st = returned_sqlstate, msg = message_text;
  end;
  return tests.check(p_name,
    case when want_state = 'any' then st <> 'no error' else st = want_state end,
    format('got %s %s, want %s', st, msg, want_state));
end;
$$;

create or replace function tests.check_ok(p_name text, sql text)
returns text
language sql
security invoker
set search_path = ''
as $$
  select tests.check_error(p_name, sql, 'no error');
$$;

-- Row count of a query as the CURRENT role, or 'denied' when it raises 42501.
create or replace function tests.count_or_denied(sql text)
returns text
language plpgsql
security invoker
set search_path = ''
as $$
declare
  c bigint;
begin
  execute 'select count(*) from (' || sql || ') q' into c;
  return c::text;
exception when insufficient_privilege then
  return 'denied';
end;
$$;

-- Expected values recorded by seed_legacy.sql.
create or replace function tests.expect(k text)
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select num from tests.seed_expect where key = k;
$$;

create or replace function tests.expect_txt(k text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select txt from tests.seed_expect where key = k;
$$;

grant usage on schema tests to anon, authenticated, service_role;
grant execute on all functions in schema tests to anon, authenticated, service_role;
