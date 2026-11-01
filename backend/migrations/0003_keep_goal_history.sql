-- Keeps one goal per account per day, so a change on a later day adds a row and
-- earlier days keep the goal they had. Must match the SQLModel model in app/goals.

ALTER TABLE user_goal ADD COLUMN effective_from date;

-- A development build of the app uploaded goals saved before the app recorded
-- save times with 1970-01-01 as their save time. Count them as saved now.
UPDATE user_goal SET updated_at = now() WHERE updated_at = '1970-01-01T00:00:00Z';

-- Existing goals apply from the UTC day they were saved.
UPDATE user_goal SET effective_from = (updated_at AT TIME ZONE 'UTC')::date;

ALTER TABLE user_goal ALTER COLUMN effective_from SET NOT NULL;
ALTER TABLE user_goal DROP CONSTRAINT user_goal_pkey;
ALTER TABLE user_goal ADD CONSTRAINT user_goal_pkey PRIMARY KEY (user_id, effective_from);
