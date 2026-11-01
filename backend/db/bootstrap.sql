-- One-time, idempotent database setup, run with scripts/bootstrap_db.sh.
-- Put things here that sit outside the app's schema: extensions, roles, grants.
-- Tables belong in migrations/*.sql, not in this file.

\set ON_ERROR_STOP on

begin;

\echo 'Connected to' :DBNAME 'on' :HOST
select current_user, version();

-- Example: enable an extension. Supabase keeps extensions in the "extensions" schema.
-- create extension if not exists pg_trgm with schema extensions;

commit;
