-- supabase/migrations/004_seed_backfill.sql
-- Backfill missing seed data for specific users using NOT EXISTS guards (idempotent).
-- Targets emails: manager.alfa@example.com, manager.beta@example.com, ref1@example.com, ref2@example.com, coach1@example.com

-- ============================================================================
-- PROFILES: ensure 2 managers + 3 talents (region Stockholm, simple bio)
-- ============================================================================

-- Manager Alfa
insert into public.profiles (id, role, full_name, region, bio)
select u.id, 'manager', 'Manager Alfa', 'Stockholm', 'Manager i Stockholm.'
from auth.users u
where u.email = 'manager.alfa@example.com'
  and not exists (select 1 from public.profiles p where p.id = u.id);

-- Manager Beta
insert into public.profiles (id, role, full_name, region, bio)
select u.id, 'manager', 'Manager Beta', 'Stockholm', 'Manager i Stockholm.'
from auth.users u
where u.email = 'manager.beta@example.com'
  and not exists (select 1 from public.profiles p where p.id = u.id);

-- Domare 1 (ref1)
insert into public.profiles (id, role, full_name, region, bio)
select u.id, 'talent', 'Domare 1', 'Stockholm', 'Talent i Stockholm.'
from auth.users u
where u.email = 'ref1@example.com'
  and not exists (select 1 from public.profiles p where p.id = u.id);

-- Domare 2 (ref2)
insert into public.profiles (id, role, full_name, region, bio)
select u.id, 'talent', 'Domare 2', 'Stockholm', 'Talent i Stockholm.'
from auth.users u
where u.email = 'ref2@example.com'
  and not exists (select 1 from public.profiles p where p.id = u.id);

-- Tränare 1 (coach1)
insert into public.profiles (id, role, full_name, region, bio)
select u.id, 'talent', 'Tränare 1', 'Stockholm', 'Talent i Stockholm.'
from auth.users u
where u.email = 'coach1@example.com'
  and not exists (select 1 from public.profiles p where p.id = u.id);

-- ============================================================================
-- TALENT_DETAILS: ensure rows with values from seed
--   ref1: 2 år, U11/U13
--   ref2: 4 år, U9/U11/U13
--   coach1: 3 år, U11/U13, hourly_rate 200
-- ============================================================================

insert into public.talent_details
  (talent_id, is_referee, is_coach, experience_years, primary_levels, travel_km, hourly_rate)
select p.id, true, false, 2, '{U11,U13}', 15, null
from public.profiles p
join auth.users u on u.id = p.id
where u.email = 'ref1@example.com'
  and not exists (select 1 from public.talent_details td where td.talent_id = p.id);

insert into public.talent_details
  (talent_id, is_referee, is_coach, experience_years, primary_levels, travel_km, hourly_rate)
select p.id, true, false, 4, '{U9,U11,U13}', 10, null
from public.profiles p
join auth.users u on u.id = p.id
where u.email = 'ref2@example.com'
  and not exists (select 1 from public.talent_details td where td.talent_id = p.id);

insert into public.talent_details
  (talent_id, is_referee, is_coach, experience_years, primary_levels, travel_km, hourly_rate)
select p.id, false, true, 3, '{U11,U13}', 20, 200
from public.profiles p
join auth.users u on u.id = p.id
where u.email = 'coach1@example.com'
  and not exists (select 1 from public.talent_details td where td.talent_id = p.id);

-- ============================================================================
-- AVAILABILITY: for all three talents, Mon/Wed/Fri (1,3,5) 18:00–20:00 (no duplicates)
-- ============================================================================
with t as (
  select p.id as talent_id
  from public.profiles p
  join auth.users u on u.id = p.id
  where u.email in ('ref1@example.com','ref2@example.com','coach1@example.com')
)
insert into public.availability (talent_id, weekday, start_time, end_time, notes)
select
  t.talent_id,
  v.weekday,
  time '18:00',
  time '20:00',
  'Seed slot'
from t
cross join (values (1),(3),(5)) as v(weekday)
where not exists (
  select 1
  from public.availability a
  where a.talent_id = t.talent_id
    and a.weekday   = v.weekday
    and a.start_time = time '18:00'
    and a.end_time   = time '20:00'
);

-- ============================================================================
-- TEAMS: one team “LinkGo IF / U13 / Stockholm” for Manager Alfa if missing
-- ============================================================================
insert into public.teams (manager_id, club_name, team_name, age_group, level, region)
select p.id, 'LinkGo IF', 'U13', 'U13', 'Medel', 'Stockholm'
from public.profiles p
join auth.users u on u.id = p.id
where u.email = 'manager.alfa@example.com'
  and not exists (
    select 1 from public.teams t
    where t.manager_id = p.id
      and t.club_name = 'LinkGo IF'
      and t.team_name = 'U13'
      and t.age_group = 'U13'
      and t.level = 'Medel'
      and t.region = 'Stockholm'
  );

-- ============================================================================
-- BOOKINGS: exactly two requested bookings if missing
--   Alfa → Ref1: tomorrow 18:00–19:30 @ Skytteholms IP (“Träningsmatch U13”)
--   Beta → Coach1: day after tomorrow 17:00–18:30 @ Zinkensdamms IP (“Teknikpass”)
-- Use CTE + UNION ALL; each branch has NOT EXISTS guard
-- ============================================================================
with m as (
  select p.id as manager_id
  from public.profiles p join auth.users u on u.id=p.id
  where u.email='manager.alfa@example.com'
),
mb as (
  select p.id as manager_id
  from public.profiles p join auth.users u on u.id=p.id
  where u.email='manager.beta@example.com'
),
r1 as (
  select p.id as talent_id
  from public.profiles p join auth.users u on u.id=p.id
  where u.email='ref1@example.com'
),
c1 as (
  select p.id as talent_id
  from public.profiles p join auth.users u on u.id=p.id
  where u.email='coach1@example.com'
)
insert into public.bookings
  (manager_id, talent_id, role_at_booking, start_ts, end_ts, location, message, status)
select
  m.manager_id, r1.talent_id, 'referee',
  (now()::date + interval '1 day') + time '18:00',
  (now()::date + interval '1 day') + time '19:30',
  'Skytteholms IP','Träningsmatch U13','requested'
from m, r1
where not exists (
  select 1 from public.bookings b
  where b.manager_id = m.manager_id
    and b.talent_id  = r1.talent_id
    and b.role_at_booking = 'referee'
    and b.start_ts = (now()::date + interval '1 day') + time '18:00'
    and b.end_ts   = (now()::date + interval '1 day') + time '19:30'
    and b.location = 'Skytteholms IP'
    and b.message  = 'Träningsmatch U13'
    and b.status   = 'requested'
)
union all
select
  mb.manager_id, c1.talent_id, 'coach',
  (now()::date + interval '2 day') + time '17:00',
  (now()::date + interval '2 day') + time '18:30',
  'Zinkensdamms IP','Teknikpass','requested'
from mb, c1
where not exists (
  select 1 from public.bookings b
  where b.manager_id = mb.manager_id
    and b.talent_id  = c1.talent_id
    and b.role_at_booking = 'coach'
    and b.start_ts = (now()::date + interval '2 day') + time '17:00'
    and b.end_ts   = (now()::date + interval '2 day') + time '18:30'
    and b.location = 'Zinkensdamms IP'
    and b.message  = 'Teknikpass'
    and b.status   = 'requested'
);

-- ============================================================================
-- Sanity SELECT: quick counts
-- ============================================================================
select
  (select count(*) from auth.users)                              as users,
  (select count(*) from public.profiles)                         as profiles,
  (select count(*) from public.talent_details)                   as talent_details,
  (select count(*) from public.availability)                     as availability,
  (select count(*) from public.teams)                            as teams,
  (select count(*) from public.bookings)                         as bookings;
