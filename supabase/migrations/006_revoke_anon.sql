-- supabase/migrations/006_revoke_anon.sql
-- Purpose: Lock down direct table access for role `anon`.
-- Effect: REVOKE SELECT, INSERT, UPDATE, DELETE on core base tables for `anon`,
--         and REVOKE ALL PRIVILEGES on ALL SEQUENCES in schema public.
-- Notes:   Views (e.g., public.v_talent_catalog) are intentionally left untouched.

-- ---------------------------------------------------------------------------
-- Announce intent in migration logs
-- ---------------------------------------------------------------------------
do $$
begin
  raise notice 'Lockdown: revoking anon privileges on base tables and sequences (views remain accessible as configured).';
end$$;

-- ---------------------------------------------------------------------------
-- Revoke on specific base tables (idempotent, guarded if tables don''t exist)
-- ---------------------------------------------------------------------------
do $$
declare
  tbl text;
  tbls text[] := array[
    'profiles',
    'talent_details',
    'availability',
    'teams',
    'bookings',
    'reviews'
  ];
begin
  foreach tbl in array tbls loop
    if to_regclass('public.'||tbl) is not null then
      execute format('REVOKE SELECT, INSERT, UPDATE, DELETE ON TABLE %I.%I FROM anon;', 'public', tbl);
      raise notice 'Revoked CRUD on %.% for role anon', 'public', tbl;
    else
      raise notice 'Skip revoke: table %.% does not exist', 'public', tbl;
    end if;
  end loop;
end$$;

-- ---------------------------------------------------------------------------
-- Revoke on all sequences in public (covers serial/bigserial/identity sequences)
-- Idempotent: revoking non-granted privileges is a no-op.
-- ---------------------------------------------------------------------------
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM anon;

-- Optional explicit sequence privilege types (USAGE, SELECT, UPDATE) kept as ALL for brevity.

-- ---------------------------------------------------------------------------
-- Final notice
-- ---------------------------------------------------------------------------
do $$
begin
  raise notice 'Anon base-table access revoked. Public read should occur via approved views only (e.g., v_talent_catalog).';
end$$;
