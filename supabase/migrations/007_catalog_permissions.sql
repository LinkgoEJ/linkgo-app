-- 007_catalog_permissions.sql
-- Tighten permissions on public.v_talent_catalog: only "authenticated" may SELECT.

-- Revoke open/default grants (safe to run many times)
REVOKE ALL ON TABLE public.v_talent_catalog FROM PUBLIC;
REVOKE ALL ON TABLE public.v_talent_catalog FROM anon;

-- Allow authenticated users to read the catalog
GRANT SELECT ON TABLE public.v_talent_catalog TO authenticated;

-- Document the decision
COMMENT ON VIEW public.v_talent_catalog IS
'LinkGo: katalog för managers. Endast authenticated har SELECT. Bas-tabeller är RLS-skyddade.';
