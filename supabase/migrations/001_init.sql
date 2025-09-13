-- supabase/migrations/001_init.sql
-- LinkGo schema init (no RLS). Idempotent with IF NOT EXISTS & defensive guards.

-- ============================================================================
-- 0) Extensions (UUID + EXCLUDE support)
-- ============================================================================
create extension if not exists pgcrypto;    -- gen_random_uuid()
create extension if not exists btree_gist;  -- GiST equality for uuid, etc.

-- ============================================================================
-- 1) Generic updated_at trigger
-- ============================================================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Helper to attach trigger 'set_updated_at' only if missing on a given table
-- Usage: DO block per table below.

-- ============================================================================
-- 2) Tables
-- ============================================================================

-- ----------------------------------------
-- profiles
-- ----------------------------------------
create table if not exists public.profiles (
  id uuid primary key
     references auth.users(id) on delete cascade,
  role text not null
     check (role in ('manager','talent')),
  full_name  text,
  avatar_url text,
  phone      text,
  region     text,
  bio        text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_profiles_role   on public.profiles(role);
create index if not exists idx_profiles_region on public.profiles(region);

do $$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgname = 'set_updated_at'
      and tgrelid = 'public.profiles'::regclass
  ) then
    create trigger set_updated_at
      before update on public.profiles
      for each row
      execute function public.set_updated_at();
  end if;
end$$;

-- ----------------------------------------
-- talent_details
-- ----------------------------------------
create table if not exists public.talent_details (
  talent_id uuid primary key
     references public.profiles(id) on delete cascade,
  is_referee boolean not null default true,
  is_coach   boolean not null default false,
  experience_years int default 0 check (experience_years >= 0),
  primary_levels   text[],
  travel_km int default 10 check (travel_km >= 0),
  hourly_rate int null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_talent_details_is_referee on public.talent_details(is_referee);
create index if not exists idx_talent_details_is_coach   on public.talent_details(is_coach);

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'set_updated_at'
      and tgrelid = 'public.talent_details'::regclass
  ) then
    create trigger set_updated_at
      before update on public.talent_details
      for each row
      execute function public.set_updated_at();
  end if;
end$$;

-- ----------------------------------------
-- availability
-- ----------------------------------------
create table if not exists public.availability (
  id bigserial primary key,
  talent_id uuid not null
    references public.profiles(id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),
  start_time time not null,
  end_time   time not null,
  notes      text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ck_availability_end_after_start check (end_time > start_time)
);

create index if not exists idx_availability_talent  on public.availability(talent_id);
create index if not exists idx_availability_weekday on public.availability(weekday);

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'set_updated_at'
      and tgrelid = 'public.availability'::regclass
  ) then
    create trigger set_updated_at
      before update on public.availability
      for each row
      execute function public.set_updated_at();
  end if;
end$$;

-- ----------------------------------------
-- teams
-- ----------------------------------------
create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  manager_id uuid not null
    references public.profiles(id) on delete cascade,
  club_name text not null,
  team_name text,
  age_group text,
  level     text,
  region    text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_teams_manager on public.teams(manager_id);
create index if not exists idx_teams_region  on public.teams(region);

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'set_updated_at'
      and tgrelid = 'public.teams'::regclass
  ) then
    create trigger set_updated_at
      before update on public.teams
      for each row
      execute function public.set_updated_at();
  end if;
end$$;

-- ----------------------------------------
-- bookings
-- ----------------------------------------
create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  manager_id uuid not null
    references public.profiles(id) on delete cascade,
  talent_id uuid not null
    references public.profiles(id) on delete cascade,
  role_at_booking text not null
    check (role_at_booking in ('referee','coach')),
  start_ts timestamptz not null,
  end_ts   timestamptz not null,
  location text,
  message  text,
  status   text not null default 'requested'
    check (status in ('requested','accepted','declined','cancelled','completed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ck_bookings_end_after_start check (end_ts > start_ts)
);

create index if not exists idx_bookings_manager  on public.bookings(manager_id);
create index if not exists idx_bookings_talent   on public.bookings(talent_id);
create index if not exists idx_bookings_status   on public.bookings(status);
create index if not exists idx_bookings_start_ts on public.bookings(start_ts);

-- No-overlap EXCLUDE constraint:
-- NOTE: Columns are timestamptz; we use tstzrange to match type (same intent as tsrange in spec).
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'bookings_no_overlap_active'
      and conrelid = 'public.bookings'::regclass
  ) then
    alter table public.bookings
      add constraint bookings_no_overlap_active
      exclude using gist (
        talent_id with =,
        tstzrange(start_ts, end_ts, '[]') with &&
      )
      where (status in ('requested','accepted'));
  end if;
end$$;

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'set_updated_at'
      and tgrelid = 'public.bookings'::regclass
  ) then
    create trigger set_updated_at
      before update on public.bookings
      for each row
      execute function public.set_updated_at();
  end if;
end$$;

-- ----------------------------------------
-- reviews
-- ----------------------------------------
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id  uuid not null references public.bookings(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  reviewee_id uuid not null references public.profiles(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists uq_reviews_booking_reviewer
  on public.reviews(booking_id, reviewer_id);

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'set_updated_at'
      and tgrelid = 'public.reviews'::regclass
  ) then
    create trigger set_updated_at
      before update on public.reviews
      for each row
      execute function public.set_updated_at();
  end if;
end$$;
