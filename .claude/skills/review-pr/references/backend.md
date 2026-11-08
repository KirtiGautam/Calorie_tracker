# Gramwise backend rules

These come from `backend/README.md`, `backend/SKILL.md` and the code as it stands. Load this file whenever the diff touches `backend/`. Where `backend/README.md` and `backend/SKILL.md` disagree, the README wins. Use the SKILL.md sections named below to settle detail questions.

## Baseline

Python 3.14, FastAPI 0.162, Pydantic v2, sync SQLModel on Supabase Postgres through `psycopg` 3, PyJWT and `pwdlib[argon2]`, managed with uv. Everything runs in Docker. Lint is `ruff check`, `ruff format --check` and `ty check`. Tests are pytest on in-memory SQLite with a 90% coverage gate.

## Hard "don'ts"

- **No secrets (Critical).** `backend/.env` must never be in the diff, and neither may a real `DATABASE_URL` password or `JWT_SECRET` anywhere. `.env.example` holds placeholders only. Don't weaken the `config.py` checks that refuse to start with `JWT_SECRET=changethis` outside development, or with a missing, blank or `DEMO_KEY` `USDA_API_KEY` in any environment.
- **Never edit a migration that has run (Critical).** A file in `backend/migrations/` that exists on the base and shows as modified, renamed or deleted breaks every deploy: `migrate.py` compares checksums and stops, and the API never starts. Check with `git diff --name-status <base>...HEAD -- backend/migrations/`. The fix is a new numbered file.
- **No new dependencies without the owner's approval (High).** Look at `[project] dependencies` and `[dependency-groups]` in `pyproject.toml`, and at `uv.lock`. The production set is listed under "Image" in `backend/README.md`.
- **No build output or caches.** Nothing from `.venv/`, `__pycache__/`, `.coverage`, `htmlcov/`, `.pytest_cache/` or `.ruff_cache/`.
- **Keep the container hardening.** The `compose.yaml` hardening block (`read_only`, `cap_drop: ALL`, `no-new-privileges`), the `.dockerignore` allow-list and the non-root `USER app` in the `Dockerfile` stay. Loosening any of them needs a reason in the PR.

## Migrations (`backend/SKILL.md` §10)

- A schema change is the next `NNNN_slug.sql` file, with a lowercase slug and a number nobody else uses. There's no Alembic and there are no down migrations.
- **The models and the SQL must match (High when they don't).** Tests build their tables from the SQLModel models with `create_all`, never from the SQL files, so drift passes every test and fails only against Postgres. Compare the new file with `app/<domain>/models.py` column by column: names, types, nullability, defaults, keys and constraints.
- Every new table gets `ALTER TABLE … ENABLE ROW LEVEL SECURITY` in the same file (High when missing).
- Each file runs in one transaction. A backfill goes in the same file and has to work on the rows already in production (see `0003_keep_goal_history.sql`). Adding a `NOT NULL` column without a default or backfill fails on a non-empty table.
- Destructive changes (`DROP`, `RENAME`, a type change) also break app builds already installed and still calling the old shape. Check them against the API contract below.

## Architecture (`backend/SKILL.md` §2, §4, §9, §11)

- **One package per domain** under `app/` (`auth`, `users`, `goals`, `daily_logs`, `health`), each with `router.py`, `schemas.py`, `models.py`, `service.py` and `exceptions.py`. Tests mirror it under `tests/`.
- **`router.py` stays thin**, and **`service.py` never imports `fastapi`.** Services raise `AppError` subclasses, never `HTTPException`.
- **Sync stack.** `SessionDep` is a sync SQLModel `Session`, so routes and dependencies are plain `def`. An `async def` route or dependency that touches the session, or calls anything blocking, stalls the event loop (High).
- **`Annotated` everywhere** (`SessionDep`, `CurrentUserDep`, `SettingsDep`, `Annotated[int, Query(ge=1, le=100)]`). No `= Depends(...)` or `= Query(...)` defaults and no `...` defaults.
- **Settings** come through `get_settings()` / `SettingsDep`, never a new module-level read. They're read at import time, which is why `tests/conftest.py` sets the environment before importing `app`.
- **Writes are committed** in the service before the route returns (`session.commit()`), never after a `yield`.

## Errors

- Domain errors subclass `app.exceptions.AppError` in `<domain>/exceptions.py`, with an HTTP `status_code` and a stable snake_case `code`. The handlers in `app/exceptions.py` turn them into `{"error": {"code", "message", "details"}}`. Anything that answers outside that envelope is High.
- Routers list their error statuses in `responses={…: {"model": ErrorEnvelope}}`, so the OpenAPI docs show them.
- No `try/except Exception` around route bodies. The catch-all handler logs and returns `internal_error`.

## Security (`backend/SKILL.md` §12)

- **Identity comes from the token.** Every route except `/health*`, `/auth/*` and `/usda/*` takes `CurrentUserDep`, and every query filters by `user.id`. The `/usda` routes are public on purpose and don't touch the database. Their guards are the per-IP rate limit and accepting only a query, a page or IDs, and removing either is High. A route that takes a user ID from the path, query or body, or that reads a row without checking whose it is, is High.
- `jwt.decode` always passes `algorithms=[...]`. Access and refresh tokens are checked for their type (`security.decode_token(…, "access", …)`).
- Login with an unknown email still verifies a dummy hash, so response timing doesn't reveal which emails have accounts. Don't remove it.
- **Bound every input (High when missing).** Every `str` has `max_length`, every list has `max_length` (see `MAX_CHANGES`, `MAX_FOODS_PER_DAY`), numbers have ranges, and list endpoints take a `limit` with `le=100` and a cursor.
- Never log passwords, tokens, `DATABASE_URL` or request bodies. Use `logging`, never `print`.

## Data and sync semantics

- Datetimes are timezone-aware everywhere: `AwareDatetime` in schemas, `UTCDateTime` columns, `datetime.now(UTC)`. A naive `datetime.now()` or `utcnow()` is a bug, because `UTCDateTime` refuses naive values.
- JSON columns use `JSONType` (JSONB on Postgres, JSON on SQLite) so tests and production agree.
- `POST /daily-logs/changes` merges by `entry_id`, so a retry gives the same result. A day whose foods were all removed stays, with `foods: []`, so the removal reaches other devices. The server recomputes the totals itself. Any change that breaks idempotency or drops empty days is High.
- Goals: a PUT for a later `effective_from` adds a row, the same day replaces it only when `updated_at` is newer, and older saves get 409 `goal_outdated`. `updated_at` is capped at the server clock. Past days' goals never change.
- `GET /daily-logs` pages oldest first with `next_cursor` / `has_more`. Check the boundaries: an empty result, exactly `limit` rows, and the last page.

## API contract with the app

- The iOS client in `CalTracker/Data/Gramwise/` decodes these responses (`GramwiseTokenPair`, `GramwiseDailyLog`, `GramwiseGoal`, …). `GramwiseClient` maps the error codes `email_taken`, `invalid_credentials`, `invalid_token`, `validation_error` and `goal_outdated` to `GramwiseAPIError`.
- Installed app builds keep calling the old shape. Renaming or removing a route, field or error code, changing a field's type, making an optional field required, or tightening validation so that values the app sends are now rejected, all break them (High). Add new fields as optional and keep existing codes.
- When routes, fields or codes change, update the route table in `backend/README.md` (Medium when stale) and the app's DTOs in the same PR, or have the PR say why not. Review both sides.

## Tests (`backend/SKILL.md` §15)

- pytest, with `tests/` mirroring `app/`. Use the fixtures in `tests/conftest.py`: `api` (a `TestClient` whose session is the in-memory SQLite database), `session`, and the `signup()` and `bearer()` helpers. The `client` fixture clears `dependency_overrides` in teardown, so new overrides go through it.
- No network and no real database. The `db.invalid` URL in `conftest.py` is never connected to.
- SQLite isn't Postgres. RLS, the migration SQL, JSONB operators and some constraints aren't exercised by tests, so review them by reading. The runner itself is tested in `tests/migrations/test_migrate.py`.
- New logic needs tests for its error paths too: 401 without a token, another account's data, each new error code, and the input bounds. A bug fix needs a test that fails without the fix.
- `./scripts/test.sh` fails below 90% coverage, which makes it a failing check (Critical).
- Ruff lets tests use `assert` and fake secrets (`S101`, `S105`, `S106`). Anywhere else, a `# noqa` needs a reason after it, as in `config.py`.

## Checklists to apply

Work through `backend/SKILL.md` §19 (anti-patterns) and §21 (pre-merge checklist), applying only the rules the diff touches. For detail questions see §4 (async), §6 (responses), §7 (Pydantic), §9 (dependencies), §10 (database and migrations), §11 (errors), §12 (security) and §15 (testing).
