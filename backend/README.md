# Gramwise backend

FastAPI service for Gramwise, backed by a Supabase Postgres database. See [SKILL.md](SKILL.md) for the coding guidelines.

Everything runs in Docker, so the only thing to install is Docker with Compose.

## Setup

```sh
cp .env.example .env        # then fill in DATABASE_URL and JWT_SECRET (openssl rand -hex 32)
./scripts/bootstrap_db.sh   # optional: runs db/bootstrap.sql against Supabase with psql, in the compose `bootstrap` service
```

Every setting comes from `.env`. Compose passes it to the containers with `env_file`, and it's never copied into an image. Outside `development`, the API refuses to start with a `JWT_SECRET` that is `changethis` or shorter than 32 bytes.

## Run

```sh
docker compose up --build
```

This builds the image, then runs two services from it in order:

1. `migrate` runs `python migrations/migrate.py` against `DATABASE_URL` and exits. It's a no-op when the database is already up to date.
2. `api` starts only after `migrate` exits successfully, so the API never runs against a schema the migration failed to reach. It listens on <http://localhost:8000>, which the iOS simulator reaches as is.

Migrations run once, in their own container, never inside the API's workers. To migrate without starting the API, use `./scripts/migrate.sh`.

### Migrations

Every schema change is a plain SQL file in `migrations/`, named `NNNN_slug.sql` (`0004_add_meal_names.sql`). `migrations/migrate.py` only runs them: it applies each file that hasn't run yet, in number order and in its own transaction, then records its name and SHA-256 in `schema_migration`. A failed file rolls back completely and stops the run, and the API doesn't start.

- **To change the schema,** add the next numbered file, and update the SQLModel models to match. Tests build their SQLite tables from the models, not from these files.
- **Never edit a file that has run.** The runner compares checksums and refuses to continue. Migrations are forward-only, so to undo a change, add a new file that reverses it.
- **Enable RLS on every new table** (`ALTER TABLE … ENABLE ROW LEVEL SECURITY`), as the existing files do, so Supabase's Data API can't read it with the anon key.

`/docs` is available when `FASTAPI_ENV` in `.env` is `development` or `staging`.

| Route | Purpose |
|---|---|
| `GET /health`, `HEAD /health` | Liveness. Always 200 while the process is up. Used by the Docker `HEALTHCHECK`. |
| `GET /health/ready`, `HEAD /health/ready` | Readiness. Runs `SELECT 1`, so it returns 503 `database_unavailable` when Postgres is down. |
| `POST /auth/signup` | `{email, password}` (8–128 characters) → 201 `TokenPair`, with `Location: /me`. 409 `email_taken`, in any letter case. |
| `POST /auth/login` | `{email, password}` → `TokenPair`. 400 `invalid_credentials` for a wrong password or an unknown email. |
| `POST /auth/refresh` | `{refresh_token}` → a new `TokenPair`. Each refresh token works once: see [Tokens](#tokens). 400 `invalid_token`. |
| `POST /auth/logout` | `{refresh_token}` → 204 after revoking it and every token it led to. Also 204 for a token that's already invalid. |
| `GET /me`, `DELETE /me` | The account `{id, email}`, or 204 after deleting it with its goal, logs and refresh tokens. |
| `GET /me/goal`, `PUT /me/goal` | The current daily targets and weight goal, the one with the latest `effective_from`. 404 `goal_not_found`. PUT saves the goal for its `effective_from` day: see below. 201 for the account's first goal, otherwise 200. 409 `goal_outdated`, 422 `invalid_goal_date`. |
| `POST /daily-logs/changes` | `{added, removed}`, up to 500 each → the touched days. Merges by `entry_id`, so retries are harmless. 422 `too_many_foods` when a day would hold more than 200 foods after the merge, counting every device's foods, and then nothing in the request is saved. |
| `GET /daily-logs?cursor=&limit=` | `{days, next_cursor, has_more}`: days changed since `cursor`, oldest first, up to 100 per page. Request again with `next_cursor` while `has_more` is true, and store the last `next_cursor` to fetch only newer changes next time. 422 `invalid_cursor` for a cursor this server didn't hand out: drop it and pull again from the start. |

Every route except `/health` and `/auth/*` needs `Authorization: Bearer <access_token>`, and returns 401 `invalid_token` without a valid one, with `WWW-Authenticate: Bearer error="invalid_token"` (or just `Bearer` when no token was sent). `TokenPair` is `{access_token, refresh_token, token_type, expires_in, user}`. Errors always use the envelope `{"error": {"code", "message", "details"}}`. Validation errors list each problem's `type`, `loc`, `msg` and `ctx`, never the value that was sent.

- **Status codes for bad requests.** Malformed JSON is 400 and a body not sent as `application/json` is 415, both with the `validation_error` code, like a 422. A body over 2 MiB is 413 `content_too_large`. A 405 lists every method the path supports in `Allow`.
- **Caching.** Every response has `Cache-Control: no-store`, and `/auth` responses also `Pragma: no-cache`, so tokens and personal data never reach a cache, including the app's on-disk `URLCache`.

### Tokens

Both tokens are HS256 JWTs signed with `JWT_SECRET`. Access tokens last 30 minutes and refresh tokens 60 days. Sign-in and refresh failures are 400, as for OAuth's `invalid_grant`, because those routes don't use HTTP authentication, so a 401 and its challenge don't apply.

Refresh tokens are rotated and stored in `refresh_token` (RFC 9700 §4.14.2). Each sign-in starts a family. Each refresh marks its token used and issues the next one in the same family. A used token that comes back more than 60 seconds later revokes the whole family, because two parties hold the same chain: the thief and the person both have to sign in again. Within 60 seconds it gets a new pair instead, so two requests from one device racing to refresh don't sign the person out. `POST /auth/logout` revokes a family. Access tokens already issued stay valid until they expire. A daily `pg_cron` job, `prune-expired-refresh-tokens` (03:17 UTC, set up by migration `0004`), deletes rows that expired more than a day ago, so the table holds about 60 days of refreshes per active account. List it with `SELECT * FROM cron.job;` and its runs with `SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;`.

Refresh tokens issued before rotation have no `fam` claim and no row. Each still works once, which turns it into the first used token of a new family. That path can go once the last of them has expired, 60 days after rotation shipped.

A `user_goal` row holds the goal from its `effective_from` day (the day it was saved, on the device that saved it) until the next row's day, so changing the goal never changes what earlier days were measured against. A PUT for a later day than the current goal adds a row. One for the same day replaces that day's goal when its `updated_at` is newer, and resending the stored goal returns it unchanged. Anything older (an earlier day, or an earlier save the same day) returns 409 `goal_outdated`, because past days' goals can't change. `effective_from` must be `updated_at`'s day in some time zone (within a day of its UTC date), or the PUT returns 422 `invalid_goal_date`. So does an `updated_at` more than 5 minutes ahead of the server's clock, which would otherwise win every later comparison. It's refused rather than capped, so the stored goal depends only on the request, and resending a PUT whose response was lost can't change it.

A `daily_log` row holds one day's foods as a JSONB list. Each item carries `entry_id`, `food_id` (`usda-…` or `off-…`), `name`, `grams`, `logged_at` (stored and returned in UTC) and the macros for the amount eaten (`energy_kcal`, `protein_g`, `carbs_g`, `fat_g`, `null` when unknown). The server recomputes the day's totals from them on every change. A day whose foods were all removed stays, with `foods: []`, so the removal reaches other devices.

## Check

```sh
./scripts/lint.sh   # ruff check, ruff format --check, ty check
./scripts/test.sh   # pytest with a 90% coverage gate; no network or database
```

Both run inside the `dev` service, an image stage with the dev dependencies. They build it on first use and bind-mount this folder, so code changes need no rebuild. The image is rebuilt only when `pyproject.toml` or `uv.lock` change. Extra arguments go to pytest: `./scripts/test.sh -k goal`.

To add a dependency, update the lockfile from the dev container, then rebuild:

```sh
docker compose run --rm dev uv add <package>    # or: uv add --dev <package>
docker compose up --build
```

## Image

Multi-stage build: uv installs locked dependencies in a builder stage, and the runtime stage copies only the venv, `app/` and `migrations/` onto `python:3.14-slim`. The `api` and `migrate` services share this image. A separate `dev` stage holds the dev dependencies for lint and tests, and never ships. It runs as a non-root user without pip. Production only installs `fastapi`, `uvicorn` (with `uvloop` and `httptools`), `pydantic-settings`, `sqlmodel`, `psycopg[binary]`, `pyjwt`, `pwdlib[argon2]` and `email-validator`. `fastapi[standard]` (the CLI, Sentry, OpenTelemetry and so on) is a dev dependency.
