-- YYYYMMDDHHMMSS_bookings_rls_policies.sql
-- Purpose: Enable RLS and define minimal, role-aware policies for public.bookings
-- Scope: READ/WRITE rules for managers and talents
-- Notes:
--  - We rely on RLS for access control; GRANTs to "authenticated" are fine but not sufficient.
--  - Service role bypasses RLS as usual.

-- 1) Ensure table exists
do $$
begin
  if not exists (
    select 1 from information_schema.tables
    where table_schema='public' and table_name='bookings'
  ) then
    raise exception 'Table public.bookings does not exist';
  end if;
end$$;

-- 2) Enable RLS
alter table public.bookings enable row level security;

-- 3) Drop existing policies if they exist (idempotent cleanup)
do $$
declare
  pol record;
begin
  for pol in
    select polname
    from pg_policy
    where polrelid = 'public.bookings'::regclass
  loop
    execute format('drop policy if exists %I on public.bookings', pol.polname);
  end loop;
end$$;

-- 4) Helper comments: expected columns
--    id (uuid), manager_id (uuid), talent_id (uuid),
--    role_at_booking (text), start_at (timestamptz), end_at (timestamptz),
--    location (text), message (text), status (text), created_at (timestamptz)

-- 5) Policies

-- 5.1 SELECT: Managers may see their own rows
create policy "bookings_select_manager_own"
on public.bookings
for select
to authenticated
using (manager_id = auth.uid());

-- 5.2 SELECT: Talents may see their own rows
create policy "bookings_select_talent_own"
on public.bookings
for select
to authenticated
using (talent_id = auth.uid());

-- 5.3 INSERT: Managers may create requests for a talent; enforce ownership + sane defaults
--     We also enforce that the inserting user is a manager via profiles.role if available.
create policy "bookings_insert_by_manager"
on public.bookings
for insert
to authenticated
with check (
  manager_id = auth.uid()
  and talent_id is not null
  and role_at_booking in ('referee','coach')
  and start_at is not null
  and end_at is not null
  and start_at < end_at
  and coalesce(status, 'requested') = 'requested'
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'manager'
  )
);

-- 5.4 UPDATE: Talent may update status on their own rows (e.g., accept/decline/confirm)
create policy "bookings_update_by_talent_own"
on public.bookings
for update
to authenticated
using (talent_id = auth.uid())
with check (talent_id = auth.uid());

-- 5.5 (Optional) UPDATE: Manager may update/cancel their own rows
--     Keep it broad for MVP; column-level restrictions can be added later via trigger if needed.
create policy "bookings_update_by_manager_own"
on public.bookings
for update
to authenticated
using (manager_id = auth.uid())
with check (manager_id = auth.uid());

-- 6) (No DELETE policy for now) — we generally avoid hard-deletes in MVP. Add later if needed.

-- 7) Verify RLS is enabled (log)
-- (No-op select for migration logs)
select 'RLS enabled on public.bookings' as info,
       (select c.relrowsecurity from pg_class c where c.oid='public.bookings'::regclass) as rls_enabled;
