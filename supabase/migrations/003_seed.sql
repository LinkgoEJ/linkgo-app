-- supabase/migrations/003_seed.sql
-- Development seed data. Skips entirely if app.env = 'prod'.

-- Guard: skip seeding in production
do $$
begin
  if current_setting('app.env', true) = 'prod' then
    raise notice '003_seed: app.env=prod → skipping seed';
    return;
  end if;

  -- ========================================================================
  -- PROFILES: upsert from existing auth.users (email confirmed in Dashboard)
  -- ========================================================================

  -- Manager Alfa
  insert into public.profiles (id, role, full_name, region, bio)
  select u.id, 'manager', 'Manager Alfa', 'Stockholm', 'Erfaren lagledare för juniorer i Stockholm.'
  from auth.users u
  where u.email = 'manager.alfa@example.com'
  on conflict (id) do nothing;

  -- Manager Beta
  insert into public.profiles (id, role, full_name, region, bio)
  select u.id, 'manager', 'Manager Beta', 'Stockholm', 'Lagledare med fokus på teknik och utveckling.'
  from auth.users u
  where u.email = 'manager.beta@example.com'
  on conflict (id) do nothing;

  -- Ref 1
  insert into public.profiles (id, role, full_name, region, bio)
  select u.id, 'talent', 'Domare 1', 'Stockholm', 'Ambitiös ungdomsdomare.'
  from auth.users u
  where u.email = 'ref1@example.com'
  on conflict (id) do nothing;

  -- Ref 2
  insert into public.profiles (id, role, full_name, region, bio)
  select u.id, 'talent', 'Domare 2', 'Stockholm', 'Trygg matchledare för yngre åldrar.'
  from auth.users u
  where u.email = 'ref2@example.com'
  on conflict (id) do nothing;

  -- Coach 1
  insert into public.profiles (id, role, full_name, region, bio)
  select u.id, 'talent', 'Tränare 1', 'Stockholm', 'Ung tränare som brinner för teknik och spelglädje.'
  from auth.users u
  where u.email = 'coach1@example.com'
  on conflict (id) do nothing;

  -- ========================================================================
  -- TALENT_DETAILS: upsert for three talents
  -- ========================================================================

  -- ref1@example.com
  insert into public.talent_details
    (talent_id, is_referee, is_coach, experience_years, primary_levels, travel_km, hourly_rate)
  select p.id, true, false, 2, '{U11,U13}', 15, null
  from public.profiles p
  join auth.users u on u.id = p.id
  where u.email = 'ref1@example.com'
  on conflict (talent_id) do nothing;

  -- ref2@example.com
  insert into public.talent_details
    (talent_id, is_referee, is_coach, experience_years, primary_levels, travel_km, hourly_rate)
  select p.id, true, false, 4, '{U9,U11,U13}', 10, null
  from public.profiles p
  join auth.users u on u.id = p.id
  where u.email = 'ref2@example.com'
  on conflict (talent_id) do nothing;

  -- coach1@example.com
  insert into public.talent_details
    (talent_id, is_referee, is_coach, experience_years, primary_levels, travel_km, hourly_rate)
  select p.id, false, true, 3, '{U11,U13}', 20, 200
  from public.profiles p
  join auth.users u on u.id = p.id
  where u.email = 'coach1@example.com'
  on conflict (talent_id) do nothing;

  -- ========================================================================
  -- AVAILABILITY: Mon/Wed/Fri (1,3,5) 18:00–20:00 for all talents
  -- Use anti-join to keep idempotent (no unique key on availability)
  -- ========================================================================
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

  -- ========================================================================
  -- TEAM for Manager Alfa (idempotent via anti-dup check + ON CONFLICT DO NOTHING)
  -- ========================================================================
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
    )
  on conflict do nothing;

  -- ========================================================================
  -- BOOKINGS: two requested bookings (idempotent with NOT EXISTS)
  -- ========================================================================
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
    where b.talent_id = r1.talent_id
      and b.start_ts = (now()::date + interval '1 day') + time '18:00'
      and b.end_ts   = (now()::date + interval '1 day') + time '19:30'
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
    where b.talent_id = c1.talent_id
      and b.start_ts = (now()::date + interval '2 day') + time '17:00'
      and b.end_ts   = (now()::date + interval '2 day') + time '18:30'
      and b.status   = 'requested'
  )
  on conflict do nothing;

end
$$;

-- ========================================================================
-- Sanity counts (visible in editor/CLI). Runs in all envs.
-- ========================================================================
select
  (select count(*) from auth.users)                                as users,
  (select count(*) from public.profiles)                           as profiles,
  (select count(*) from public.talent_details)                     as talent_details,
  (select count(*) from public.availability)                       as availability,
  (select count(*) from public.teams)                              as teams,
  (select count(*) from public.bookings where status='requested')  as bookings_requested;
