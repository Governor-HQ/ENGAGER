-- =====================================================================
-- Engager — Supabase schema
-- Run this whole file once in: Supabase Dashboard → SQL Editor → New query
-- =====================================================================

-- ---------------------------------------------------------------------
-- "Today" for the class. Every rule about "one post per day" uses this,
-- so the day rolls over at the same moment for everyone.
-- Change 'UTC' to your class's timezone, e.g. 'Africa/Lagos',
-- 'America/New_York', 'Europe/London'.
-- ---------------------------------------------------------------------
create or replace function public.app_today()
returns date
language sql
stable
as $$
  select (now() at time zone 'Africa/Lagos')::date;
$$;

-- ---------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------
create table public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  full_name  text not null check (char_length(trim(full_name)) between 1 and 100),
  created_at timestamptz not null default now()
);

create table public.posts (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  url        text not null
             check (char_length(url) <= 500)
             -- Only LinkedIn links. Also blocks javascript:/data: URLs from ever
             -- reaching an href on other students' screens.
             check (url ~* '^https://([a-z0-9-]+\.)*(linkedin\.com|lnkd\.in)(/|$)'),
  post_date  date not null default public.app_today(),
  created_at timestamptz not null default now(),
  constraint posts_one_per_user_per_day unique (user_id, post_date)
);

create table public.engagements (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.posts (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint engagements_once_per_post unique (post_id, user_id)
);

create index posts_post_date_idx      on public.posts (post_date);
create index engagements_user_id_idx  on public.engagements (user_id);

-- ---------------------------------------------------------------------
-- Rule: you cannot engage with your own post.
-- A CHECK constraint can't look at another table, so a trigger enforces it.
-- Triggers run for every role (including service_role), so this can't be
-- bypassed from the API.
-- ---------------------------------------------------------------------
create or replace function public.prevent_self_engagement()
returns trigger
language plpgsql
as $$
begin
  if exists (
    select 1 from public.posts p
    where p.id = new.post_id and p.user_id = new.user_id
  ) then
    raise exception 'You cannot engage with your own post'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger engagements_no_self_engagement
  before insert or update on public.engagements
  for each row execute function public.prevent_self_engagement();

-- ---------------------------------------------------------------------
-- Create the profile row automatically when someone signs up.
-- full_name comes from the signup form (passed as user metadata).
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), 'Student')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- Row Level Security
-- Everyone signed in can read everything (shared class tool).
-- Inserts are only allowed for your own rows.
-- No UPDATE or DELETE policies exist, so those are denied for everyone.
-- ---------------------------------------------------------------------
alter table public.profiles    enable row level security;
alter table public.posts       enable row level security;
alter table public.engagements enable row level security;

-- profiles
create policy "Signed-in users can read profiles"
  on public.profiles for select to authenticated
  using (true);

create policy "Users can insert their own profile"
  on public.profiles for insert to authenticated
  with check (id = auth.uid());

-- posts
create policy "Signed-in users can read posts"
  on public.posts for select to authenticated
  using (true);

create policy "Users can insert their own post for today"
  on public.posts for insert to authenticated
  with check (user_id = auth.uid() and post_date = public.app_today());

-- engagements
create policy "Signed-in users can read engagements"
  on public.engagements for select to authenticated
  using (true);

create policy "Users can insert their own engagements"
  on public.engagements for insert to authenticated
  with check (user_id = auth.uid());
