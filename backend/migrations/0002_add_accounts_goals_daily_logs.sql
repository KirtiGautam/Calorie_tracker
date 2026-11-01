-- Accounts, their goal and targets, and one row of logged foods per day.
-- Must match the SQLModel models in app/users, app/goals and app/daily_logs.

CREATE TABLE app_user (
    id uuid NOT NULL,
    -- Stored trimmed and lowercased, so the unique constraint ignores letter case.
    email varchar(254) NOT NULL,
    hashed_password varchar(255) NOT NULL,
    created_at timestamptz NOT NULL,
    CONSTRAINT app_user_pkey PRIMARY KEY (id),
    CONSTRAINT app_user_email_key UNIQUE (email)
);

CREATE TABLE user_goal (
    user_id uuid NOT NULL,
    goal varchar(16) NOT NULL,
    energy_kcal double precision,
    protein_g double precision,
    carbs_g double precision,
    fat_g double precision,
    -- When the person saved the goal on their device. The newest save wins.
    updated_at timestamptz NOT NULL,
    CONSTRAINT user_goal_pkey PRIMARY KEY (user_id),
    CONSTRAINT user_goal_goal_check CHECK (goal IN ('cut', 'maintain', 'bulk')),
    CONSTRAINT user_goal_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_user (id) ON DELETE CASCADE
);

CREATE TABLE daily_log (
    user_id uuid NOT NULL,
    log_date date NOT NULL,
    -- Computed by the server from `foods`. NULL when no food reports the macro.
    energy_kcal double precision,
    protein_g double precision,
    carbs_g double precision,
    fat_g double precision,
    foods jsonb NOT NULL,
    -- Set by the server on every change, for pulls.
    updated_at timestamptz NOT NULL,
    CONSTRAINT daily_log_pkey PRIMARY KEY (user_id, log_date),
    CONSTRAINT daily_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_user (id) ON DELETE CASCADE
);

-- Pulls page through one account's days by (updated_at, log_date).
CREATE INDEX daily_log_user_id_updated_at_log_date_idx ON daily_log (user_id, updated_at, log_date);

-- RLS with no policies, so Supabase's Data API can't read these tables (and
-- `hashed_password`) with the anon key.
ALTER TABLE app_user ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_goal ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_log ENABLE ROW LEVEL SECURITY;
