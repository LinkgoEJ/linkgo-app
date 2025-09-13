-- supabase/migrations/002_security.sql
-- Security, RLS policies, status guards, and catalog view (idempotent)

set search_path = public, pg_temp;

-- ============================================================================
-- 1) Enable RLS
-- ============================================================================
alter table if exists public.profiles       enable row level security;
alter table if exists public.talent_details enable row level security;
alter table if exists public.availability   enable row level security;
alter table if exists public.teams          enable row level security;
alter table if exists public.bookings       enable row level security;
alter table if exists public.reviews        enable row level security;

-- ============================================================================
-- 2) POLICIES (create if missing via guards)
-- ============================================================================

-- ----------------------------
-- profiles
-- ----------------------------
do $$
begin
  if not exists (select 1 from pg_policy where polname='profiles_ins_self' and polrelid='public.profiles'::regclass) then
    create policy profiles_ins_self
      on public.profiles
      for insert
      with check (id = auth.uid());
    comment on policy profiles_ins_self on public.profiles is
      'INSERT only when creating own profile (id = auth.uid()).';
  end if;

  if not exists (select 1 from pg_policy where polname='profiles_sel_owner' and polrelid='public.profiles'::regclass) then
    create policy profiles_sel_owner
      on public.profiles
      for select
      using (id = auth.uid());
    comment on policy profiles_sel_owner on public.profiles is
      'SELECT allowed only for row owner (auth.uid() = id).';
  end if;

  if not exists (select 1 from pg_policy where polname='profiles_upd_owner' and polrelid='public.profiles'::regclass) then
    create policy profiles_upd_owner
      on public.profiles
      for update
      using (id = auth.uid())
      with check (id = auth.uid());
    comment on policy profiles_upd_owner on public.profiles is
      'UPDATE allowed only for row owner (auth.uid() = id).';
  end if;

  if not exists (select 1 from pg_policy where polname='profiles_del_owner' and polrelid='public.profiles'::regclass) then
    create policy profiles_del_owner
      on public.profiles
      for delete
      using (id = auth.uid());
    comment on policy profiles_del_owner on public.profiles is
      'DELETE allowed only for row owner (auth.uid() = id).';
  end if;
end$$;

-- ----------------------------
-- talent_details (owner via profiles + role='talent')
-- ----------------------------
do $$
begin
  if not exists (select 1 from pg_policy where polname='talent_details_ins_owner' and polrelid='public.talent_details'::regclass) then
    create policy talent_details_ins_owner
      on public.talent_details
      for insert
      with check (exists (
        select 1 from public.profiles p
        where p.id = talent_details.talent_id
          and p.id = auth.uid()
          and p.role = 'talent'
      ));
    comment on policy talent_details_ins_owner on public.talent_details is
      'INSERT only by owner; requires profiles.role = ''talent''.';
  end if;

  if not exists (select 1 from pg_policy where polname='talent_details_sel_owner' and polrelid='public.talent_details'::regclass) then
    create policy talent_details_sel_owner
      on public.talent_details
      for select
      using (exists (
        select 1 from public.profiles p
        where p.id = talent_details.talent_id
          and p.id = auth.uid()
          and p.role = 'talent'
      ));
    comment on policy talent_details_sel_owner on public.talent_details is
      'SELECT only by owner; requires profiles.role = ''talent''.';
  end if;

  if not exists (select 1 from pg_policy where polname='talent_details_upd_owner' and polrelid='public.talent_details'::regclass) then
    create policy talent_details_upd_owner
      on public.talent_details
      for update
      using (exists (
        select 1 from public.profiles p
        where p.id = talent_details.talent_id
          and p.id = auth.uid()
          and p.role = 'talent'
      ))
      with check (exists (
        select 1 from public.profiles p
        where p.id = talent_details.talent_id
          and p.id = auth.uid()
          and p.role = 'talent'
      ));
    comment on policy talent_details_upd_owner on public.talent_details is
      'UPDATE only by owner; requires profiles.role = ''talent''.';
  end if;

  if not exists (select 1 from pg_policy where polname='talent_details_del_owner' and polrelid='public.talent_details'::regclass) then
    create policy talent_details_del_owner
      on public.talent_details
      for delete
      using (exists (
        select 1 from public.profiles p
        where p.id = talent_details.talent_id
          and p.id = auth.uid()
          and p.role = 'talent'
      ));
    comment on policy talent_details_del_owner on public.talent_details is
      'DELETE only by owner; requires profiles.role = ''talent''.';
  end if;
end$$;

-- ----------------------------
-- availability (owner is talent_id)
-- ----------------------------
do $$
begin
  if not exists (select 1 from pg_policy where polname='availability_ins_owner' and polrelid='public.availability'::regclass) then
    create policy availability_ins_owner
      on public.availability
      for insert
      with check (talent_id = auth.uid());
    comment on policy availability_ins_owner on public.availability is
      'INSERT only when talent_id = auth.uid().';
  end if;

  if not exists (select 1 from pg_policy where polname='availability_sel_owner' and polrelid='public.availability'::regclass) then
    create policy availability_sel_owner
      on public.availability
      for select
      using (talent_id = auth.uid());
    comment on policy availability_sel_owner on public.availability is
      'SELECT only by row owner (talent_id = auth.uid()).';
  end if;

  if not exists (select 1 from pg_policy where polname='availability_upd_owner' and polrelid='public.availability'::regclass) then
    create policy availability_upd_owner
      on public.availability
      for update
      using (talent_id = auth.uid())
      with check (talent_id = auth.uid());
    comment on policy availability_upd_owner on public.availability is
      'UPDATE only by row owner (talent_id = auth.uid()).';
  end if;

  if not exists (select 1 from pg_policy where polname='availability_del_owner' and polrelid='public.availability'::regclass) then
    create policy availability_del_owner
      on public.availability
      for delete
      using (talent_id = auth.uid());
    comment on policy availability_del_owner on public.availability is
      'DELETE only by row owner (talent_id = auth.uid()).';
  end if;
end$$;

-- ----------------------------
-- teams (owner is manager_id)
-- ----------------------------
do $$
begin
  if not exists (select 1 from pg_policy where polname='teams_ins_owner' and polrelid='public.teams'::regclass) then
    create policy teams_ins_owner
      on public.teams
      for insert
      with check (manager_id = auth.uid());
    comment on policy teams_ins_owner on public.teams is
      'INSERT only when manager_id = auth.uid().';
  end if;

  if not exists (select 1 from pg_policy where polname='teams_sel_owner' and polrelid='public.teams'::regclass) then
    create policy teams_sel_owner
      on public.teams
      for select
      using (manager_id = auth.uid());
    comment on policy teams_sel_owner on public.teams is
      'SELECT only by row owner (manager_id = auth.uid()).';
  end if;

  if not exists (select 1 from pg_policy where polname='teams_upd_owner' and polrelid='public.teams'::regclass) then
    create policy teams_upd_owner
      on public.teams
      for update
      using (manager_id = auth.uid())
      with check (manager_id = auth.uid());
    comment on policy teams_upd_owner on public.teams is
      'UPDATE only by row owner (manager_id = auth.uid()).';
  end if;

  if not exists (select 1 from pg_policy where polname='teams_del_owner' and polrelid='public.teams'::regclass) then
    create policy teams_del_owner
      on public.teams
      for delete
      using (manager_id = auth.uid());
    comment on policy teams_del_owner on public.teams is
      'DELETE only by row owner (manager_id = auth.uid()).';
  end if;
end$$;

-- ----------------------------
-- bookings (parties: manager_id, talent_id)
-- ----------------------------
do $$
begin
  if not exists (select 1 from pg_policy where polname='bookings_ins_manager_only' and polrelid='public.bookings'::regclass) then
    create policy bookings_ins_manager_only
      on public.bookings
      for insert
      with check (manager_id = auth.uid());
    comment on policy bookings_ins_manager_only on public.bookings is
      'INSERT only when auth.uid() = manager_id.';
  end if;

  if not exists (select 1 from pg_policy where polname='bookings_sel_parties' and polrelid='public.bookings'::regclass) then
    create policy bookings_sel_parties
      on public.bookings
      for select
      using (auth.uid() in (manager_id, talent_id));
    comment on policy bookings_sel_parties on public.bookings is
      'SELECT allowed for booking parties (manager or talent).';
  end if;

  if not exists (select 1 from pg_policy where polname='bookings_upd_parties' and polrelid='public.bookings'::regclass) then
    create policy bookings_upd_parties
      on public.bookings
      for update
      using (auth.uid() in (manager_id, talent_id))
      with check (auth.uid() in (manager_id, talent_id));
    comment on policy bookings_upd_parties on public.bookings is
      'UPDATE allowed for parties only; status changes validated by trigger.';
  end if;
end$$;

-- ----------------------------
-- reviews
-- ----------------------------
create or replace function public.can_insert_review(p_booking uuid, p_reviewer uuid)
returns boolean
language sql
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.bookings b
    where b.id = p_booking
      and b.status = 'completed'
      and p_reviewer in (b.manager_id, b.talent_id)
  )
$$;
comment on function public.can_insert_review(uuid, uuid) is
  'Returns true if booking exists, is completed, and reviewer was a party in the booking.';

do $$
begin
  if not exists (select 1 from pg_policy where polname='reviews_ins_completed_party' and polrelid='public.reviews'::regclass) then
    create policy reviews_ins_completed_party
      on public.reviews
      for insert
      with check (
        reviewer_id = auth.uid()
        and public.can_insert_review(booking_id, auth.uid())
      );
    comment on policy reviews_ins_completed_party on public.reviews is
      'INSERT only by reviewer and only for completed booking where reviewer was a party.';
  end if;

  if not exists (select 1 from pg_policy where polname='reviews_sel_owner_or_party' and polrelid='public.reviews'::regclass) then
    create policy reviews_sel_owner_or_party
      on public.reviews
      for select
      using (
        reviewer_id = auth.uid()
        or exists (
          select 1 from public.bookings b
          where b.id = reviews.booking_id
            and auth.uid() in (b.manager_id, b.talent_id)
        )
      );
    comment on policy reviews_sel_owner_or_party on public.reviews is
      'SELECT allowed to review owner or any party in the related booking.';
  end if;

  if not exists (select 1 from pg_policy where polname='reviews_upd_owner' and polrelid='public.reviews'::regclass) then
    create policy reviews_upd_owner
      on public.reviews
      for update
      using (reviewer_id = auth.uid())
      with check (reviewer_id = auth.uid());
    comment on policy reviews_upd_owner on public.reviews is
      'UPDATE allowed only by reviewer (owner).';
  end if;

  if not exists (select 1 from pg_policy where polname='reviews_del_owner' and polrelid='public.reviews'::regclass) then
    create policy reviews_del_owner
      on public.reviews
      for delete
      using (reviewer_id = auth.uid());
    comment on policy reviews_del_owner on public.reviews is
      'DELETE allowed only by reviewer (owner).';
  end if;
end$$;

-- ============================================================================
-- 3) Status-guard for bookings (function + trigger)
-- ============================================================================
create or replace function public.validate_booking_status_transition()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
begin
  if new.status = old.status then
    return new;
  end if;

  if old.status in ('declined','completed','cancelled') then
    raise exception 'invalid status transition';
  end if;

  if old.status = 'requested' then
    if new.status not in ('accepted','declined','cancelled') then
      raise exception 'invalid status transition';
    end if;
    if new.status in ('accepted','declined') and v_uid <> old.talent_id then
      raise exception 'invalid status transition';
    end if;
    if new.status = 'cancelled' and v_uid <> old.manager_id then
      raise exception 'invalid status transition';
    end if;

  elsif old.status = 'accepted' then
    if new.status not in ('cancelled','completed') then
      raise exception 'invalid status transition';
    end if;
    if new.status = 'cancelled' and v_uid <> old.manager_id then
      raise exception 'invalid status transition';
    end if;
    if new.status = 'completed' and v_uid not in (old.manager_id, old.talent_id) then
      raise exception 'invalid status transition';
    end if;
  end if;

  return new;
end;
$$;
comment on function public.validate_booking_status_transition() is
  'Guards allowed booking status transitions and which party may perform them.';

do $$
begin
  if not exists (select 1 from pg_trigger where tgname='trg_bookings_validate_status' and tgrelid='public.bookings'::regclass) then
    create trigger trg_bookings_validate_status
      before update of status on public.bookings
      for each row
      execute function public.validate_booking_status_transition();
  end if;
end$$;

-- ============================================================================
-- 4) Catalog via SECURITY DEFINER
-- ============================================================================
create or replace function public.get_talent_catalog()
returns table(
  id uuid,
  full_name text,
  region text,
  is_referee boolean,
  is_coach boolean,
  experience_years int,
  primary_levels text[],
  travel_km int,
  hourly_rate int,
  bio text
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    p.id,
    coalesce(p.full_name,'') as full_name,
    coalesce(p.region,'')    as region,
    coalesce(td.is_referee,false) as is_referee,
    coalesce(td.is_coach,false)   as is_coach,
    coalesce(td.experience_years,0) as experience_years,
    td.primary_levels,
    coalesce(td.travel_km,0) as travel_km,
    td.hourly_rate,
    left(coalesce(p.bio,''), 240) as bio
  from public.profiles p
  join public.talent_details td on td.talent_id = p.id
  where p.role = 'talent'
$$;
comment on function public.get_talent_catalog() is
  'SECURITY DEFINER: sanitized public-facing talent catalog (no phone/PII beyond short bio).';

create or replace view public.v_talent_catalog as
  select * from public.get_talent_catalog();

comment on view public.v_talent_catalog is
  'Public catalog view for talents, backed by SECURITY DEFINER function; base tables remain protected by RLS.';

grant select on public.v_talent_catalog to anon, authenticated;

-- ============================================================================
-- 5) Guard trigger for talent_details: only profiles with role='talent'
-- ============================================================================
create or replace function public.enforce_talent_details_role()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1
    from public.profiles p
    where p.id = new.talent_id
      and p.role = 'talent'
  ) then
    raise exception 'only talent profiles can have talent_details';
  end if;
  return new;
end;
$$;
comment on function public.enforce_talent_details_role() is
  'Prevents INSERT/UPDATE of talent_details unless linked profile has role=''talent''.';

do $$
begin
  if not exists (select 1 from pg_trigger where tgname='trg_talent_details_only_for_talent' and tgrelid='public.talent_details'::regclass) then
    create trigger trg_talent_details_only_for_talent
      before insert or update on public.talent_details
      for each row
      execute function public.enforce_talent_details_role();
  end if;
end$$;

-- ============================================================================
-- 6) Table-level comments
-- ============================================================================
comment on table public.profiles       is 'RLS enabled: owner-only access by id = auth.uid().';
comment on table public.talent_details is 'RLS enabled: owner-only via profiles join; profile role must be ''talent''.';
comment on table public.availability   is 'RLS enabled: owner-only by talent_id = auth.uid().';
comment on table public.teams          is 'RLS enabled: owner-only by manager_id = auth.uid().';
comment on table public.bookings       is 'RLS enabled: parties-only (manager/talent); status transitions guarded by trigger.';
comment on table public.reviews        is 'RLS enabled: reviewer-owned; insert requires completed booking where reviewer was a party.';
