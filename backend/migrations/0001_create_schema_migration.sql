-- Records which migration files have run. migrations/migrate.py reads it to skip them,
-- and adds a row after each file it applies.
CREATE TABLE schema_migration (
    version varchar(255) NOT NULL,
    -- SHA-256 of the file, so an applied migration that was edited afterwards is caught.
    checksum char(64) NOT NULL,
    applied_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT schema_migration_pkey PRIMARY KEY (version)
);

-- Supabase's Data API exposes `public` tables to the anon key. RLS with no policies
-- closes that door. The app connects as the table owner, which RLS doesn't restrict.
ALTER TABLE schema_migration ENABLE ROW LEVEL SECURITY;
