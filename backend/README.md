# Gramwise backend

FastAPI service for Gramwise, backed by a Supabase Postgres database. See [SKILL.md](SKILL.md) for the coding guidelines.

Everything runs in Docker, so the only thing to install is Docker with Compose.

## Setup

```sh
cp .env.example .env        # then fill in DATABASE_URL and JWT_SECRET (openssl rand -hex 32)
./scripts/bootstrap_db.sh   # optional: runs db/bootstrap.sql against Supabase with psql from the postgres image
```

Every setting comes from `.env`. Compose passes it to the containers with `env_file`, and it's never copied into an image.

## Run

```sh
docker compose up --build
```

This builds the image, then runs two services from it in order:

1. `migrate` runs `python migrations/migrate.py` against `DATABASE_URL` and exits. It's a no-op when the database is already up to date.
2. `api` starts only after `migrate` exits successfully, so the API never runs against a schema the migration failed to reach. It listens on <http://localhost:8000>, which the iOS simulator reaches as is.

Migrations run once, in their own container, never inside the API's workers. To migrate without starting the API, use `./scripts/migrate.sh`.

### Migrations

Every schema change is a plain SQL file in `migrations/`, named `NNNN_slug.sql` (`0003_add_meal_names.sql`). `migrations/migrate.py` only runs them: it applies each file that hasn't run yet, in number order and in its own transaction, then records its name and SHA-256 in `schema_migration`. A failed file rolls back completely and stops the run, and the API doesn't start.

- **To change the schema,** add the next numbered file, and update the SQLModel models to match. Tests build their SQLite tables from the models, not from these files.
- **Never edit a file that has run.** The runner compares checksums and refuses to continue. Migrations are forward-only, so to undo a change, add a new file that reverses it.
- **Enable RLS on every new table** (`ALTER TABLE … ENABLE ROW LEVEL SECURITY`), as the existing files do, so Supabase's Data API can't read it with the anon key.

`/docs` is available when `FASTAPI_ENV` in `.env` is `development` or `staging`.

| Route | Purpose |
|---|---|
| `GET /health` | Liveness. Always 200 while the process is up. Used by the Docker `HEALTHCHECK`. |
| `GET /health/ready` | Readiness. Runs `SELECT 1`, so it returns 503 `database_unavailable` when Postgres is down. |
| `POST /auth/signup` | `{email, password}` (8–128 characters) → 201 `TokenPair`. 409 `email_taken`, in any letter case. |
| `POST /auth/login` | `{email, password}` → `TokenPair`. 401 `invalid_credentials` for a wrong password or an unknown email. |
| `POST /auth/refresh` | `{refresh_token}` → a new `TokenPair`. 401 `invalid_token`. |
| `GET /me`, `DELETE /me` | The account `{id, email}`, or 204 after deleting it with its goal and logs. |
| `GET /me/goal`, `PUT /me/goal` | The current daily targets and weight goal, the one with the latest `effective_from`. 404 `goal_not_found`. PUT saves the goal for its `effective_from` day: see below. 409 `goal_outdated`, 422 `invalid_goal_date`. |

Every route except `/health` and `/auth/*` needs `Authorization: Bearer <access_token>`, and returns 401 `invalid_token` without a valid one. `TokenPair` is `{access_token, refresh_token, token_type, expires_in, user}`. Both tokens are HS256 JWTs signed with `JWT_SECRET`. Access tokens last 30 minutes and refresh tokens 60 days. Errors always use the envelope `{"error": {"code", "message", "details"}}`.

A `user_goal` row holds the goal from its `effective_from` day (the day it was saved, on the device that saved it) until the next row's day, so changing the goal never changes what earlier days were measured against. A PUT for a later day than the current goal adds a row. One for the same day replaces that day's goal when its `updated_at` is newer, and resending the stored goal returns it unchanged. Anything older (an earlier day, or an earlier save the same day) returns 409 `goal_outdated`, because past days' goals can't change. `effective_from` must be `updated_at`'s day in some time zone (within a day of its UTC date), or the PUT returns 422 `invalid_goal_date`. `updated_at` is capped at the server's clock.

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
