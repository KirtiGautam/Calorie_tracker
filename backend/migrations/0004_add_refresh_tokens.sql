-- Refresh tokens the server issued, so each can be used once and a whole sign-in
-- can be revoked. Must match the SQLModel model in app/auth.

CREATE TABLE refresh_token (
    -- The token's `jti` claim.
    jti varchar(64) NOT NULL,
    -- Shared by every token one sign-in leads to.
    family_id uuid NOT NULL,
    user_id uuid NOT NULL,
    issued_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    -- When the token was exchanged for the next one.
    used_at timestamptz,
    -- When the family was signed out or caught being reused.
    revoked_at timestamptz,
    CONSTRAINT refresh_token_pkey PRIMARY KEY (jti),
    CONSTRAINT refresh_token_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_user (id) ON DELETE CASCADE
);

CREATE INDEX ix_refresh_token_family_id ON refresh_token (family_id);
CREATE INDEX ix_refresh_token_user_id ON refresh_token (user_id);
-- For the daily cleanup below, so it doesn't scan the whole table.
CREATE INDEX ix_refresh_token_expires_at ON refresh_token (expires_at);

-- RLS with no policies, so Supabase's Data API can't read it with the anon key.
ALTER TABLE refresh_token ENABLE ROW LEVEL SECURITY;

-- Every refresh adds a row, so expired ones are deleted daily, inside the database
-- rather than by the API's replicas. A token that has expired can't be presented,
-- so its row, used or revoked, is no longer needed. The day of slack keeps a token
-- refused for reuse until well after its own expiry check would refuse it anyway.
-- pg_cron is on Supabase; its control file requires the pg_catalog schema.
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;

-- 03:17 UTC, off the hour when other jobs tend to run. Scheduling a name that
-- already exists replaces that job.
SELECT cron.schedule(
    'prune-expired-refresh-tokens',
    '17 3 * * *',
    $$DELETE FROM refresh_token WHERE expires_at < now() - interval '1 day'$$
);
