---
name: fastapi-backend-expert
description: Consolidated guidance for writing, reviewing, and testing FastAPI services, covering project structure, async vs sync, Pydantic v2, dependencies, SQLModel/SQLAlchemy and this project's plain-SQL migrations, error handling, security, testing, tooling, and deployment. Distilled from the official FastAPI agent skill, zhanymkanov/fastapi-best-practices, the official Full Stack FastAPI Template, and fulit103/fastapi-clean, then checked against FastAPI 0.162.0. Use whenever creating or modifying Python code under backend/.
---

# FastAPI Backend Expert

Distilled from the sources in the [Source Index](#source-index) (read 2026-10-27). The official FastAPI skill is the backbone because it ships inside the `fastapi` package and is updated with every release. zhanymkanov's guide adds production structure, the Full Stack template shows a complete working service, and fastapi-clean adds layering for complex modules. Where the sources disagree, this file picks one and says why.

Items marked **(verified)** were run on 2026-10-27 against FastAPI 0.162.0 (released 2026-10-23), Pydantic 2.14.1, SQLModel, and Ruff 0.17.3, instead of being taken on trust from a source.

---

## 0. Operating Principles

1. **Check the installed version before relying on memory.** FastAPI shipped many breaking and behavior-changing releases in 2026 (see §18), so training data and older blog posts are often wrong. The lockfile is the authority. The official skill ships inside the package at `.venv/lib/python3.*/site-packages/fastapi/.agents/skills/fastapi/` **(verified)**. Read it when the installed version is newer than 0.162.0.
2. **Never block the event loop.** It's the most common FastAPI bug and the most expensive one (§4).
3. **Stay in scope.** Make the requested change. Suggest unrelated modernization separately and don't apply it unless asked.
4. **Ask before adding a dependency** beyond the baseline stack in §1.
5. **Never commit secrets.** `.env` files stay untracked. Commit a `.env.example` with placeholders.
6. **Verify every change:** `ruff check`, `ruff format --check`, `ty check`, then `pytest`. Unit tests never touch the network (§15).
7. **Review output format:** group findings by file and line, name the rule, show a short before/after, and end with a prioritized summary. For "write" or "fix" requests, change the code directly.

---

## 1. Baseline Stack

| Concern | Default | Notes |
|---|---|---|
| Python | 3.14 for new projects (what the official template targets) | FastAPI needs 3.10 or newer. 3.9 support was dropped in 0.129.0. Don't go below 3.11 here (`StrEnum`, `typing.Self`). |
| Packages | uv (`uv add`, `uv sync --frozen`, `uv run`) | Commit `uv.lock`. |
| Framework | `fastapi[standard]` | Includes fastapi-cli, uvicorn[standard], httpx, pydantic-settings, pydantic-extra-types, email-validator, python-multipart, jinja2, and the OpenTelemetry SDK with the OTLP exporter. `fastapi-slim` is discontinued. |
| Validation | Pydantic v2 (2.9 or newer) | Pydantic v1 and `pydantic.v1` are unsupported since 0.128.0. |
| Settings | pydantic-settings | §8 |
| Database | SQLModel on PostgreSQL through `psycopg[binary]` 3 | This is the pick of the official skill and the template. For an async-first codebase, use SQLAlchemy 2.0 `AsyncSession` instead (§10). Pick one per project. |
| Migrations | Numbered plain-SQL files run by `migrations/migrate.py` | §10. The sources use Alembic. This project doesn't, and `README.md` is the authority. |
| Outbound HTTP | HTTPX | Not `requests`, which is sync-only and blocks inside `async def`. |
| Sync/async bridge | Asyncer (`asyncify`, `syncify`) | The official skill's pick. `fastapi.concurrency.run_in_threadpool` does the same without an extra dependency. |
| Auth | PyJWT and `pwdlib[argon2]` | Not `python-jose` (unmaintained) or `passlib` (the official tutorial moved to pwdlib). |
| Jobs | `BackgroundTasks` for tiny work, otherwise Celery, Arq or RQ | §13 |
| Lint and format | Ruff with the `FAST` and `ASYNC` rules | §16 |
| Types | ty (`ty check`) | Pre-1.0. The template also runs `mypy --strict`. |
| Tests | pytest with `TestClient` or `httpx.AsyncClient`, plus coverage | §15 |

---

## 2. Project Structure

Organize by **domain**, not by file type. File-type layouts (`routes/`, `models.py`, `crud.py`, as in the template) suit small services but stop scaling once there are several domains. This layout follows zhanymkanov (who based it on Netflix Dispatch) and uses the `app` package name from the official docs and template.

```
backend/
├── pyproject.toml          # dependencies, [tool.fastapi] entrypoint, ruff/ty/pytest config
├── uv.lock
├── .env.example            # placeholder values only; .env itself is never committed
├── compose.yaml            # migrate (release step), api, and dev (lint and tests) services
├── migrations/             # NNNN_slug.sql files, plus migrate.py, the runner (§10)
├── db/bootstrap.sql        # one-time database setup, run by scripts/bootstrap_db.sh
├── scripts/                # lint.sh, test.sh, migrate.sh, bootstrap_db.sh
├── app/
│   ├── __init__.py         # sets the database naming convention (§10)
│   ├── main.py             # lifespan, middleware, exception handlers, routers
│   ├── config.py           # global Settings + get_settings()
│   ├── database.py         # engine + SessionDep
│   ├── dependencies.py     # app-wide dependencies (HTTP client, current user)
│   ├── exceptions.py       # AppError base + register_exception_handlers()
│   ├── foods/              # one package per domain
│   │   ├── router.py       # endpoints only, kept thin
│   │   ├── schemas.py      # request/response models (FoodCreate, FoodPublic)
│   │   ├── models.py       # table models (Food)
│   │   ├── service.py      # business logic, never imports fastapi
│   │   ├── dependencies.py # validate-and-load dependencies (valid_food_id)
│   │   ├── client.py       # outbound client for an external API, if any
│   │   ├── config.py       # domain-scoped settings, if any
│   │   ├── constants.py    # error codes and enums
│   │   └── exceptions.py   # FoodNotFound, ...
│   └── auth/
└── tests/                  # mirrors app/: tests/foods/, tests/auth/, tests/fixtures/
```

- **Keep `router.py` thin.** It declares parameters, calls a service or dependency, and returns. Plain CRUD may use the session directly in the router, as the template and the official SQL tutorial do. Move logic into `service.py` as soon as there are business rules, outbound calls, or a second caller such as a worker, CLI or script.
- **`service.py` never imports `fastapi`.** It raises domain exceptions (§11), never `HTTPException`, so workers and scripts can call it too.
- **Import other domains by module name:** `from app.auth import service as auth_service` or `from app.foods.constants import ErrorCode as FoodErrorCode`. Never use `import *` or reach deep into another domain's internals.
- **Use a `typing.Protocol` only where the real thing hurts in tests**, meaning network, secrets, latency or flaky errors. A concrete ORM session against a test database is fine. This is fastapi-clean's rule: "does having the real implementation hurt in tests?"
- **Add full Domain, Application and Infrastructure layers only when they pay off.** That means entities, use cases, ports and adapters for a module that has an external integration, several triggers (HTTP, worker, CLI), non-trivial rules, or several data sources in one operation. Never add them for plain CRUD, where empty layers are just noise.
- **`main.py` and the lifespan are the composition root.** They create clients and register routers and handlers. Nothing does I/O at import time.

---

## 3. App Setup: CLI, Lifespan, Docs

```toml
# pyproject.toml
[tool.fastapi]
entrypoint = "app.main:app"
```

- `fastapi dev` runs locally with reload. It sets `FASTAPI_ENV=development` unless the variable is already set. `fastapi run` runs the production server and leaves `FASTAPI_ENV` alone, so set it explicitly in deployments.
- Use `lifespan` for startup and shutdown. `@app.on_event` is deprecated, and once `lifespan` is set, event handlers don't run.
- Create shared resources (HTTP clients, engines, caches) once in the lifespan, and hand them out through dependencies.
- Hide the docs unless the API is public. `openapi_url=None` turns off `/docs`, `/redoc` and the schema **(verified)**. Make "hidden" the default so a missing variable fails safe.
- Don't pass `root_path=` to `FastAPI()`. It's deprecated since 0.146; use `fastapi run --root-path /prefix` instead.

```python
# app/main.py
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI

from app.config import get_settings
from app.exceptions import register_exception_handlers
from app.foods.router import router as foods_router


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    async with httpx.AsyncClient(timeout=10) as http_client:
        app.state.http_client = http_client
        yield


settings = get_settings()
app = FastAPI(
    title="Backend API",
    lifespan=lifespan,
    openapi_url="/openapi.json" if settings.show_docs else None,
)
register_exception_handlers(app)
app.include_router(foods_router)
```

```python
# app/dependencies.py
from typing import Annotated

import httpx
from fastapi import Depends, Request


async def get_http_client(request: Request) -> httpx.AsyncClient:
    return request.app.state.http_client


HTTPClientDep = Annotated[httpx.AsyncClient, Depends(get_http_client)]
```

---

## 4. Async vs Sync

FastAPI awaits `async def` functions on the event loop and runs plain `def` functions in a threadpool. Dependencies follow the same rule.

| The function... | Declare it | Why |
|---|---|---|
| only awaits non-blocking I/O (HTTPX `AsyncClient`, an async DB driver, `asyncio.sleep`) | `async def` | Cheapest option. No thread needed. |
| does trivial work with no I/O (reads a header, checks a claim, returns something from `app.state`) | `async def` | Skips the threadpool hop. |
| calls anything blocking (a sync ORM session, `requests`, `open()`, `time.sleep`, a sync SDK) | `def` | Runs in the threadpool, so the loop keeps serving other requests. |
| is mostly async but has one blocking call | `async def` plus `await asyncify(fn)(...)` or `await run_in_threadpool(fn, ...)` | Offloads only the blocking part. |
| is CPU-heavy (roughly over 50 ms) | hand it to a worker process or task queue | Because of the GIL, threads don't help CPU work, and neither does `await`. |
| you aren't sure | `def` | The official skill's default. A wrong `def` costs a thread. A wrong `async def` stalls every request on that worker. |

- A blocking call inside `async def` seems to work in development but freezes the whole worker under load.
- The threadpool is finite (AnyIO's default limit is 40 threads). Slow sync endpoints and sync dependencies all share it.
- Ruff's `ASYNC` rules catch the common cases: `ASYNC210` for blocking HTTP, `ASYNC230` for `open()`, and `ASYNC251` for `time.sleep` **(verified)**.

---

## 5. Path Operations and Routing

- Use `Annotated` for every parameter and dependency. It keeps signatures valid Python, so they work outside FastAPI too, and lets you reuse the type.

  ```python
  router = APIRouter(prefix="/foods", tags=["foods"])


  @router.get("/{food_id}", response_model=FoodPublic)
  def read_food(
      food_id: Annotated[int, Path(ge=1)],
      session: SessionDep,
      fields: Annotated[str | None, Query(max_length=50)] = None,
  ) -> Any: ...
  ```

- Never use `...` as a default (`Query(...)`, `Field(...)`, `name: str = ...`). Parameters are required unless you give a default.
- Put `prefix`, `tags` and shared `dependencies=[Depends(...)]` on the `APIRouter`, not in `include_router()`. Version the API with an aggregate router: `api_router = APIRouter(prefix="/api/v1")`.
- Write one function per HTTP method. Don't use `@app.api_route(methods=["GET", "POST"])` and branch on `request.method`.
- Set explicit status codes from `fastapi.status`: `HTTP_201_CREATED` on create, and `HTTP_204_NO_CONTENT` with no body on delete.
- Use the same path-parameter name everywhere a resource appears (`/foods/{food_id}`, `/meals/{meal_id}/foods/{food_id}`), so one `valid_food_id` dependency covers all of them.
- Group related query parameters into a model: `filters: Annotated[FoodFilter, Query()]`. With `model_config = {"extra": "forbid"}`, a typo like `?limti=5` returns 422 **(verified)**. Since 0.160, the model's `extra` setting applies to every query parameter on the route, including ones declared elsewhere. Header, cookie and form models work the same way. They can be combined (0.157) and made optional (0.159).
- Document for generated clients. Add a `summary`, write docstrings (they become descriptions), and declare non-2xx shapes with `responses={404: {"model": ErrorEnvelope}}`. Set `generate_unique_id_function` so generated clients get clean method names. The template uses `f"{route.tags[0]}-{route.name}"`.
- Treat `router.routes` as internal. Since 0.137 it's a tree, not a flat list. Use `iter_route_contexts()` for introspection.

---

## 6. Responses and Serialization

- **Declare a return type.** FastAPI uses it to validate the response, filter it (fields outside the type are dropped), document it, and serialize it in Pydantic's Rust core. That last step arrived in 0.130 and roughly doubles JSON speed.
- **When the returned object isn't the public type** (a table model, or an internal model holding secrets), set `response_model=FoodPublic` and annotate `-> Any`. This is the official SQL tutorial's pattern, and it keeps the type checker honest.
- **Never return a table model without a public response model.** Doing so leaks columns like `hashed_password`.
- **Don't set `response_class=JSONResponse`, and don't use `ORJSONResponse` or `UJSONResponse`** (deprecated in 0.131). Any explicit `response_class` turns off the Rust fast path and falls back to `jsonable_encoder` plus `json.dumps` **(verified in `fastapi/routing.py`)**.
- **Returning a model instance runs its validators twice**: once when your code builds it, and again when FastAPI validates the response. Returning a dict or an ORM object runs them once **(verified with both a return type and `response_model`. Older advice that "dropping `response_model` avoids this" is wrong)**. Keep response-model validators cheap and free of side effects, and put expensive checks on request models. Ruff `FAST001` flags a `response_model` that only repeats the return type.
- **Streaming** (0.134 and later):
  - JSON Lines: declare `-> AsyncIterable[Item]` and `yield` items.
  - Server-Sent Events: set `response_class=EventSourceResponse` from `fastapi.sse`, then `yield` models or `ServerSentEvent(data=..., event=..., id=...)`. Use `raw_data=` for pre-formatted text.
  - Bytes: subclass `StreamingResponse` with a `media_type`, pass the subclass as `response_class=`, and `yield` chunks. Don't return a `StreamingResponse` instance.
- **Built single-page frontends:** use `app.frontend("/", directory="dist")` (0.138 and later) instead of mounting `StaticFiles` by hand. API routes are matched first.

---

## 7. Pydantic v2 Models

- **Separate models by role**, with a shared base (this is the template and SQL tutorial pattern):

  ```python
  from sqlmodel import Field, SQLModel


  class FoodBase(SQLModel):
      name: str = Field(min_length=1, max_length=200)
      kcal_per_100g: float = Field(ge=0, le=900)


  class Food(FoodBase, table=True):  # database row
      id: int | None = Field(default=None, primary_key=True)
      owner_id: int = Field(foreign_key="user.id", index=True)


  class FoodCreate(FoodBase):  # POST body; owner comes from the token, not the client
      pass


  class FoodUpdate(SQLModel):  # PATCH body; every field optional
      name: str | None = Field(default=None, min_length=1, max_length=200)
      kcal_per_100g: float | None = Field(default=None, ge=0, le=900)


  class FoodPublic(FoodBase):  # response
      id: int
  ```

- **Constrain every input field.** Use `min_length`/`max_length` on strings and lists, `ge`/`gt`/`le` on numbers, and `pattern=`, `EmailStr`, `HttpUrl`, `StrEnum` or `Literal` where they fit. Bounds also cap payload size.
- **Optional means the type includes `None`:** `x: int | None = Field(default=None, ge=0)`. Never write `x: int = Field(default=None)`. Since 0.148, defaults aren't validated unless `validate_default=True` is set, so that silently puts `None` in an `int` field.
- **JSON `null` isn't the same as an omitted field** (0.151 and later). `null` is validated as `None`, so a non-nullable field rejects it even if it has a default. Make a field `| None` if clients are allowed to clear it.
- **For PATCH,** use `food.sqlmodel_update(food_in.model_dump(exclude_unset=True))` so omitted fields stay untouched **(verified)**. With plain Pydantic, use `model_copy(update=...)`.
- **Use v2 APIs only.** That means `model_config = ConfigDict(...)` (never an inner `class Config`), `@field_validator` and `@model_validator(mode="after")` (never `@validator` or `@root_validator`), and `.model_dump()` / `.model_validate()` (never `.dict()` or `.parse_obj()`).
- **A `ValueError` raised inside a validator becomes a 422** with field details. Use this for cross-field rules.
- **No `RootModel`.** Use plain annotations instead, such as `items: Annotated[list[int], Field(min_length=1), Body()]`. FastAPI builds the `TypeAdapter` for you.
- **For custom output formats,** use `@field_serializer` or `Annotated[T, PlainSerializer(...)]`. `json_encoders` is deprecated. Avoid a wildcard `@field_serializer("*")` on a shared base model, because it calls a Python function for every field of every response.
- **Datetimes:** generate timezone-aware UTC values with `datetime.now(UTC)`, accept `AwareDatetime` on input, and name the columns `*_at` (§10).
- Use `SecretStr` for secrets in models and settings, so they don't leak through `repr` or logs. Use `computed_field` for derived output values.

---

## 8. Settings and Secrets

```python
# app/config.py
from functools import lru_cache
from typing import Annotated, Literal

from fastapi import Depends
from pydantic import PostgresDsn, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_ignore_empty=True, extra="ignore"
    )

    fastapi_env: Literal["development", "staging", "production"] = "production"
    database_url: PostgresDsn  # postgresql+psycopg://... for psycopg 3
    jwt_secret: SecretStr

    @property
    def show_docs(self) -> bool:
        return self.fastapi_env != "production"


@lru_cache
def get_settings() -> Settings:
    return Settings()


SettingsDep = Annotated[Settings, Depends(get_settings)]
```

- `fastapi_env` reads the `FASTAPI_ENV` variable that `fastapi dev` sets. It defaults to production, so a missing variable fails safe.
- Read settings through `get_settings()`, or `SettingsDep` in routes, so tests can swap them with `app.dependency_overrides[get_settings]` **(verified)**. `@lru_cache` builds the object only once.
- Once the global class grows, split it into per-domain classes (for example `AuthSettings` with `env_prefix="AUTH_"`), each with its own cached getter.
- Fail fast at startup. Give required fields no default, and add a `model_validator` that rejects placeholder secrets such as `changethis` outside development (the template does this).
- `.env` is for local development only and is never committed. Production secrets come from the environment or a secret manager.

---

## 9. Dependencies

- Use a dependency when the logic can't be expressed as Pydantic validation, needs an external resource, needs cleanup, reads request data, or is shared across endpoints (for example auth or early errors).
- Give each dependency an `Annotated` alias and reuse it, such as `SessionDep`, `CurrentUserDep` or `FoodDep`.
- **Validate and load.** A dependency takes the path parameter, loads the resource, and raises if it's missing. Every route that uses it gets the check for free, and the dependencies chain:

  ```python
  # app/foods/dependencies.py
  def valid_food_id(food_id: int, session: SessionDep) -> Food:
      food = session.get(Food, food_id)
      if food is None:
          raise FoodNotFound(f"Food {food_id} not found", {"food_id": food_id})
      return food


  FoodDep = Annotated[Food, Depends(valid_food_id)]


  def valid_owned_food(food: FoodDep, user: CurrentUserDep) -> Food:
      if food.owner_id != user.id:
          # 404 rather than 403, so other users' food IDs can't be probed.
          raise FoodNotFound(f"Food {food.id} not found", {"food_id": food.id})
      return food


  OwnedFoodDep = Annotated[Food, Depends(valid_owned_food)]
  ```

- **Results are cached per request.** When both `valid_food_id` and the route use `SessionDep`, they get the same session. Opt out with `Depends(fn, use_cache=False)`.
- **Ruff caveat:** `FAST003` misfires when a path parameter is consumed by a dependency behind an `Annotated` alias like `FoodDep`. It only follows inline `Annotated[..., Depends(fn)]` **(verified, Ruff 0.17.3)**. Add `# noqa: FAST003` to those routes, and don't apply its unsafe fix, which adds an unused parameter.
- **For `yield` dependencies,** put cleanup in `finally`. If you catch an exception with `except`, re-raise it or raise a new one. Otherwise the client gets a 500 and nothing appears in the logs.
- **Know when the exit code runs.** With the default `scope="request"`, code after `yield` runs *after the response has been sent*. A commit placed there that fails still sends the client a 200 **(verified)**. Commit inside the route or service before returning, and keep the dependency's exit code for closing and rolling back. Use `Depends(fn, scope="function")` when exit code must finish before the response goes out.
- **Side-effect-only dependencies** (an auth gate, a rate limit) go on the router: `APIRouter(dependencies=[Depends(require_user)])`.
- **Avoid class dependencies** like `Annotated[Paginator, Depends()]`. Write a function that returns a dataclass instance instead.
- **`Depends` is for wiring and request-level checks.** Business workflows belong in services.

---

## 10. Database: SQLModel, SQLAlchemy, Migrations

```python
# app/__init__.py — runs before any table model is defined, so constraint names are predictable
from sqlmodel import SQLModel

SQLModel.metadata.naming_convention = {
    "ix": "%(column_0_label)s_idx",
    "uq": "%(table_name)s_%(column_0_name)s_key",
    "ck": "%(table_name)s_%(constraint_name)s_check",
    "fk": "%(table_name)s_%(column_0_name)s_fkey",
    "pk": "%(table_name)s_pkey",
}
```

The naming convention produces names like `food_pkey`, `food_owner_id_fkey` and `owner_email_idx` **(verified)**.

```python
# app/database.py — sync SQLModel (the default): use plain def routes and dependencies
from collections.abc import Iterator
from typing import Annotated

from fastapi import Depends
from sqlmodel import Session, create_engine

from app.config import get_settings

engine = create_engine(str(get_settings().database_url), pool_pre_ping=True)


def get_session() -> Iterator[Session]:
    with Session(engine) as session:
        yield session


SessionDep = Annotated[Session, Depends(get_session)]
```

- **Async alternative** (SQLAlchemy 2.0): `create_async_engine(...)`, `async_sessionmaker(engine, expire_on_commit=False)`, and an `async def get_session() -> AsyncIterator[AsyncSession]` that does `async with SessionFactory() as session: yield session`. Use `async def` routes and dependencies throughout. psycopg 3 supports async, and so does `asyncpg`. Never call a sync session from `async def`.
- **Use one session per request**, which the cached dependency gives you. Commit explicitly where the unit of work ends (see §9), then `refresh` before returning.

  ```python
  @router.post("/", status_code=status.HTTP_201_CREATED, response_model=FoodPublic)
  def create_food(food_in: FoodCreate, session: SessionDep, user: CurrentUserDep) -> Any:
      food = Food.model_validate(food_in, update={"owner_id": user.id})
      session.add(food)
      session.commit()
      session.refresh(food)
      return food
  ```

- **Create tables only through migrations.** `SQLModel.metadata.create_all()` is only for tests, which build their in-memory SQLite tables from the models (`tests/conftest.py`).
- **Naming:** use `lower_snake_case` and singular table names (`food`, `meal_entry`). Give related tables a shared module prefix (`meal`, `meal_entry`). Use `_at` for datetimes and `_date` for dates. Keep a foreign key's name the same everywhere (`food_id`), and use a more specific name only where the meaning differs (`creator_id`).
- **SQL first:** filter, join, aggregate, sort and paginate in SQL, not in Python loops. Build nested JSON in Postgres (`json_build_object`) when that simplifies a response. Load relationships eagerly (`selectinload`) instead of lazy-loading in a loop, which causes N+1 queries.
- **Paginate every list endpoint** with a bounded `limit` (`Field(default=20, ge=1, le=100)`).
- **Unique constraints are the source of truth.** Check first so you can return a friendly error, but still map `IntegrityError` to 409 for races.
- **Migrations.** The sources recommend Alembic. This project uses plain SQL files instead, as `README.md` describes, and `README.md` wins where the two differ.
  - Every schema change is the next numbered file in `migrations/`, named `NNNN_slug.sql` with a lowercase slug (`0004_add_meal_names.sql`). `migrate.py` refuses a badly named file or a reused number.
  - Write the SQL by hand. Nothing is generated, so check the file against the models line by line.
  - Update the SQLModel models in the same change so they match. Tests build their tables from the models, never from these files, so a mismatch passes every test and fails only against Postgres.
  - Each file runs in its own transaction, and the runner records its name and SHA-256 in `schema_migration`. A failing file rolls back and stops the run, and the API doesn't start.
  - Migrations are forward-only, with no down migrations. **Never edit, rename or delete a file that has run.** The runner compares checksums and refuses to continue. To change or undo something, add a new file.
  - Only the data may be dynamic, never the structure. A backfill goes in the same file as the column it fills, and must work on the rows already there (see `0003_keep_goal_history.sql`).
  - Enable row level security on every new table (`ALTER TABLE … ENABLE ROW LEVEL SECURITY`), so Supabase's Data API can't read it with the anon key.
  - Migrations run once, in the compose `migrate` service, before `api` starts, or with `./scripts/migrate.sh`. Never run them at app startup, where several workers would race.

---

## 11. Errors

- **Services raise domain exceptions** that subclass a single `AppError` with a `status_code` and a stable `code`. Routers and dependencies may raise `HTTPException` directly, because they are the HTTP layer. Prefer `AppError` subclasses for anything a client needs to branch on.
- **Use one envelope for every error,** including validation errors and unknown routes: `{"error": {"code", "message", "details"}}`. Clients branch on `code` and show their own localized text. `message` is for developers.
- **Register handlers** for **Starlette's** `HTTPException` (which also catches router 404 and 405), for `RequestValidationError`, and as a catch-all that logs and returns a generic 500 without internals **(verified)**. Keep `exc.headers` so `WWW-Authenticate` survives.

```python
# app/exceptions.py
import logging
from typing import Any

from fastapi import FastAPI, Request, status
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

logger = logging.getLogger(__name__)


class AppError(Exception):
    """Base for domain errors. Subclasses set an HTTP status and a stable code."""

    status_code: int = status.HTTP_400_BAD_REQUEST
    code: str = "bad_request"

    def __init__(self, message: str, details: dict[str, Any] | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.details = details


def error_response(
    status_code: int,
    code: str,
    message: str,
    details: Any = None,
    headers: dict[str, str] | None = None,
) -> JSONResponse:
    content = {"error": {"code": code, "message": message, "details": details}}
    return JSONResponse(status_code=status_code, content=content, headers=headers)


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def handle_app_error(request: Request, exc: AppError) -> JSONResponse:
        return error_response(exc.status_code, exc.code, exc.message, exc.details)

    @app.exception_handler(StarletteHTTPException)
    async def handle_http_error(
        request: Request, exc: StarletteHTTPException
    ) -> JSONResponse:
        headers = dict(exc.headers) if exc.headers else None
        return error_response(
            exc.status_code, "http_error", str(exc.detail), headers=headers
        )

    @app.exception_handler(RequestValidationError)
    async def handle_validation_error(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        return error_response(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "validation_error",
            "Request validation failed",
            jsonable_encoder(exc.errors()),
        )

    @app.exception_handler(Exception)
    async def handle_unexpected(request: Request, exc: Exception) -> JSONResponse:
        logger.exception("Unhandled error on %s %s", request.method, request.url.path)
        return error_response(
            status.HTTP_500_INTERNAL_SERVER_ERROR,
            "internal_error",
            "Internal server error",
        )
```

```python
# app/foods/exceptions.py
class FoodNotFound(AppError):
    status_code = status.HTTP_404_NOT_FOUND
    code = "food_not_found"
```

| Situation | Status |
|---|---|
| Missing or invalid credentials | 401 with `WWW-Authenticate: Bearer` |
| Authenticated but not allowed | 403, or 404 if you don't want to reveal that the resource exists |
| Not found | 404 |
| Uniqueness or state conflict | 409 |
| Precondition failed (stale `If-Match`) | 412 |
| Validation failure | 422 |
| Rate limited | 429 |
| An upstream API failed or timed out | 502 or 504 |

- Don't wrap route bodies in `try/except Exception`. It hides bugs and can turn failures into 200s. Catch specific exceptions only.
- Map outbound failures (`httpx.HTTPStatusError`, `httpx.TimeoutException`) to a domain error in `client.py`, so the client gets a 502 or 504 instead of a generic 500.

---

## 12. Security

- **Passwords:** hash with `pwdlib` and Argon2 (`PasswordHash.recommended()`). To migrate old bcrypt hashes, build `PasswordHash((Argon2Hasher(), BcryptHasher()))` and use `verify_and_update()` to rehash on login, as the template does. When a username doesn't exist, still verify against a dummy hash, so response timing doesn't reveal which usernames are real (the official tutorial does this).
- **Tokens:** use PyJWT. Always pass `algorithms=[...]` to `jwt.decode`, keep access tokens short-lived, put the user ID in `sub`, and generate the secret with `openssl rand -hex 32`. Catch `jwt.InvalidTokenError` and return 401 with `WWW-Authenticate: Bearer`.
- **Identity:** take the acting user from the token (`CurrentUserDep`), never from an ID the client sends. Check ownership in a dependency (`valid_owned_food`) or in the service.
- **API keys:** generate them with `secrets.token_urlsafe`, store only a SHA-256 hash, and compare with `hmac.compare_digest` (fastapi-clean).
- **Keep `strict_content_type` on.** It's the default since 0.132: JSON bodies without a JSON `Content-Type` are rejected **(verified, 422)**. Turn it off only for clients you can't fix.
- **Bound every input** (§7) and every list endpoint (§10). Validate upload size and type.
- **CORS is a browser mechanism,** so native mobile clients don't need it. For browser clients, list exact origins from settings. Never combine `allow_origins=["*"]` with `allow_credentials=True`.
- **Behind a TLS-terminating proxy,** run `fastapi run --proxy-headers --forwarded-allow-ips=<proxy IP>`. Use `"*"` only when nothing but the proxy can reach the app.
- **Rate limiting isn't built in.** Do it at the proxy or gateway, or in a router dependency backed by Redis.
- **Never log** passwords, tokens, API keys, or full request bodies containing personal data. Hide the docs in production (§3).

---

## 13. Background Work

| Use `BackgroundTasks` when... | Use Celery, Arq or RQ when... |
|---|---|
| the task is short (under a second) | it takes seconds to minutes |
| losing it silently is acceptable | you need retries, a dead-letter queue, or visibility |
| it's in-process work (send one email, write a log row) | it's CPU-heavy or needs its own worker pool |
| you don't need scheduling | you need cron, ETA scheduling, or rate limits |

- `BackgroundTasks` run after the response, in the same worker process. If the worker dies, the task is lost. Rule of thumb: if you'd page someone when the task is lost, it doesn't belong there.
- Wrap background functions so exceptions get logged with `logger.exception`. Otherwise failures disappear without a trace.
- Queue tasks are thin adapters that call services. Make critical tasks idempotent (with an idempotency key), and retry only transient errors.

---

## 14. Observability

- Log with `logging`, never `print` (Ruff `T20` flags it). Use `logger.exception` in handlers so the traceback is kept.
- Add request IDs. A middleware reads `X-Request-ID` (or generates a UUID), stores it on `request.state`, echoes it in the response, and adds it to log records and error bodies.
- OpenTelemetry is built in (0.142 and later), and `fastapi[standard]` includes the SDK and the OTLP/HTTP exporter. Automatic exporter setup has been opt-in since 0.143. Set `FASTAPI_OTEL_AUTO_CONFIGURE=true`, `OTEL_SERVICE_NAME` and `OTEL_EXPORTER_OTLP_ENDPOINT`, plus `OTEL_EXPORTER_OTLP_HEADERS` if the collector needs auth. Alternatively, configure it in code with `FastAPI(telemetry={...})`.
- Expose a cheap, unauthenticated `/health` liveness route. Add a separate readiness check that touches the database if the platform supports one.
- Error tracking is optional. The template uses `sentry-sdk[fastapi]` and skips it in development.

---

## 15. Testing

- Use pytest, with `tests/` mirroring `app/`. Structure each test as Arrange, Act, Assert. Assert on the status code and body, not internals. Test services directly, without HTTP, when they hold the logic.
- **Sync stack:** use `TestClient` as a context manager so the lifespan runs.

  ```python
  # tests/conftest.py
  @pytest.fixture
  def client() -> Iterator[TestClient]:
      with TestClient(app) as c:
          yield c
      app.dependency_overrides.clear()
  ```

- **Async stack** (an async DB, or async helpers in tests): use `httpx.AsyncClient` with `ASGITransport` and `@pytest.mark.anyio`. AnyIO's pytest plugin ships with FastAPI and runs on asyncio by default, so you don't need pytest-asyncio **(verified)**. `AsyncClient` doesn't run the lifespan, so either wrap the app in `asgi_lifespan.LifespanManager` or set up state in fixtures.

  ```python
  @pytest.mark.anyio
  async def test_missing_food_returns_404() -> None:
      transport = ASGITransport(app=app)
      async with AsyncClient(transport=transport, base_url="http://test") as client:
          response = await client.get("/foods/999")

      assert response.status_code == 404
      assert response.json()["error"]["code"] == "food_not_found"
  ```

- **Swap dependencies** with `app.dependency_overrides[original] = replacement`. Don't monkeypatch internals, and clear the overrides in fixture teardown.
- **No live network calls.** Outbound clients come from a dependency, so tests can substitute `httpx.MockTransport` serving JSON fixtures from `tests/fixtures/` **(verified)**:

  ```python
  def test_lookup_reads_fixture(client: TestClient) -> None:
      payload = json.loads((FIXTURES / "peanut_butter.json").read_text())

      def handler(request: httpx.Request) -> httpx.Response:
          assert request.url.path == "/products/737628064502"
          return httpx.Response(200, json=payload)

      async def fake_http_client() -> AsyncIterator[httpx.AsyncClient]:
          async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as c:
              yield c

      app.dependency_overrides[get_http_client] = fake_http_client

      response = client.get("/lookup/737628064502")

      assert response.status_code == 200
  ```

- Fakes implement the whole `Protocol`. Avoid loose `MagicMock` objects that accept any call.
- **Integration tests use a real database** of the same engine as production (Postgres in Docker, or testcontainers), isolated per test with a rolled-back transaction or truncation. Don't mock the database in integration tests, and remember that SQLite behaves differently from Postgres. For quick in-memory SQLite tests, use `poolclass=StaticPool` and `connect_args={"check_same_thread": False}` so every session sees the same database.
- `TestClient` takes JSON-ready data, so pass `json=food_in.model_dump(mode="json")`, not a model instance.
- `TestClient` re-raises server exceptions by default. Use `TestClient(app, raise_server_exceptions=False)` to assert on a 500 response body.
- Enforce a coverage gate in CI. The template uses `coverage report --fail-under=90`.

---

## 16. Tooling

```toml
[tool.ruff]
target-version = "py314"

[tool.ruff.lint]
select = ["E", "W", "F", "I", "B", "C4", "UP", "ASYNC", "FAST", "T20", "S", "PT"]
ignore = ["E501"]  # line length is the formatter's job

[tool.ruff.lint.per-file-ignores]
"tests/**" = ["S101"]  # pytest relies on assert

[tool.ty.terminal]
error-on-warning = true

[tool.pytest.ini_options]
testpaths = ["tests"]
```

- **The `FAST` rules:** `FAST001` flags a redundant `response_model`, `FAST002` flags a dependency without `Annotated`, and `FAST003` flags an unused path parameter (see the caveat in §9).
- **Keep `B008` on,** unlike the template, which ignores it. With `Annotated` everywhere it never fires on correct code, and it catches `x = Depends(...)` defaults that `FAST002` misses when the parameter has no annotation **(verified)**.
- **`S`** (bandit) catches things like `requests` calls without a timeout. **`PT`** keeps pytest style consistent.
- **Everyday commands:**

  ```sh
  uv run fastapi dev                                   # local server with reload
  uv run ruff check --fix . && uv run ruff format .    # lint and format
  uv run ty check                                      # types
  uv run pytest                                        # tests
  ```

- Put the lint commands in `scripts/lint.sh` (`ruff check`, `ruff format --check`, `ty check`) and the test commands in `scripts/test.sh` (coverage plus pytest). CI runs both. Pre-commit hooks are optional.

---

## 17. Deployment

```dockerfile
FROM python:3.14-slim
COPY --from=ghcr.io/astral-sh/uv:0.9.26 /uv /uvx /bin/
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy PATH="/app/.venv/bin:$PATH"
WORKDIR /app

# Dependencies first, so code changes don't invalidate this layer.
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen --no-install-project --no-dev

COPY . /app
RUN --mount=type=cache,target=/root/.cache/uv uv sync --frozen --no-dev

CMD ["fastapi", "run", "--workers", "4"]
```

- Always use the exec form of `CMD`, as above, so signals reach the server and lifespan shutdown runs.
- On a single machine, use `--workers` to use several cores. On Kubernetes or similar, run one process per container and scale replicas instead.
- Keep `.venv`, `.env` and `tests/` out of the image with `.dockerignore`.
- Run migrations as a separate release step before the new code starts serving. Here that's the compose `migrate` service, which `api` waits for (§10).
- Set `FASTAPI_ENV=production` explicitly, because `fastapi run` doesn't set it.
- When the app is served under a path prefix, use `fastapi run --root-path /api`.

---

## 18. 2026 Changes That Stale Knowledge Gets Wrong

| Version | Change | What to do |
|---|---|---|
| 0.125 to 0.128 (Dec 2025) | Python 3.8 dropped. Pydantic v1 dropped, and `pydantic.v1` removed in 0.128. | Use Pydantic v2 APIs only. |
| 0.129.0 (Feb 2026) | Python 3.9 dropped. | Use Python 3.10 or newer and `X \| None` syntax. |
| 0.129.2 | `fastapi-slim` discontinued. | Depend on `fastapi` or `fastapi[standard]`. |
| 0.130 | Rust JSON serialization when there's a return type or `response_model`. | Declare one. Don't set a custom `response_class`. |
| 0.131 | `ORJSONResponse` and `UJSONResponse` deprecated. | Remove them. |
| 0.132 | `strict_content_type` on by default. | Clients must send `application/json`. `strict_content_type=False` opts out. |
| 0.134, 0.135 | Streaming with `yield` (JSON Lines, bytes) and Server-Sent Events (`fastapi.sse`). | See §6. |
| 0.137 | `router.routes` is now a tree, and routes added after `include_router()` work. | Don't iterate or mutate `routes`. Use `iter_route_contexts()`. |
| 0.138 | `app.frontend()` and `router.frontend()` added. | Use them instead of `StaticFiles` for SPAs. |
| 0.142, 0.143 | Native OpenTelemetry. Exporter auto-setup is opt-in. | Set `FASTAPI_OTEL_AUTO_CONFIGURE=true`. |
| 0.144 | Security dependencies work with WebSockets. | |
| 0.145, 0.146 | `openapi_prefix` removed. `FastAPI(root_path=...)` deprecated. | Use `fastapi run --root-path`. |
| 0.148 | Defaults are not validated unless `validate_default=True`, and applied defaults don't count as "set". | Use `T \| None` for `None` defaults (§7). |
| 0.149, 0.150, 0.153 | In forms, empty strings and unselected file inputs count as missing. | |
| 0.151 | JSON `null` is distinct from an omitted value. | Make clearable fields `\| None`. |
| 0.152 | Header-model errors report HTTP header names (`int-val`). | Update tests that assert on error locations. |
| 0.155 | `**extra` removed from `Path`, `Query`, `Header`, `Cookie`, `Body`, `Form` and `File`. | Use `json_schema_extra={...}`. Unknown kwargs now raise `TypeError`. |
| 0.160 | A parameter model's `extra` setting applies to sibling parameters. | Watch out for `extra="forbid"` (§5). |
| 0.162 | Omitted bool form fields use their declared default again (0.147 had made them `False`). | Declare HTML checkboxes as `bool = False`. |
| Older | `@app.on_event` deprecated. `fastapi.middleware.wsgi.WSGIMiddleware` deprecated. | Use `lifespan` and `a2wsgi`. |

---

## 19. Anti-Patterns (review checklist)

| Anti-pattern | Fix |
|---|---|
| `requests`, `time.sleep`, `open()` or a sync session inside `async def` | The async equivalent, or make the function `def` (§4) |
| `x: T = Depends(dep)` or `q: str = Query(None)` | `Annotated[T, Depends(dep)]`, `Annotated[str \| None, Query()] = None` |
| `...` as a default, or a `RootModel` | Omit the default; use plain annotations |
| `ORJSONResponse`, or `response_class=JSONResponse` "for speed" | A return type or `response_model` |
| Returning a table model with no public response model | `response_model=XPublic` with `-> Any` |
| `x: int = Field(default=None)` | `x: int \| None = Field(default=None)` |
| `class Config`, `.dict()`, `@validator`, `json_encoders` | Pydantic v2 APIs (§7) |
| `@app.on_event("startup")` | `lifespan` |
| `from jose import jwt`, or `passlib` | PyJWT, `pwdlib[argon2]` |
| `HTTPException` raised inside a service | A domain exception plus a handler (§11) |
| `try/except Exception` around a route body | Catch specific exceptions only |
| `session.commit()` after `yield` with the default scope | Commit in the route or service, or use `scope="function"` (§9) |
| `except` in a `yield` dependency without re-raising | Re-raise, or raise a new exception |
| `BackgroundTasks` for work you can't lose | A real task queue (§13) |
| `prefix=` or `tags=` on `include_router()` | Set them on the `APIRouter` |
| `@app.api_route(methods=[...])` branching on the method | One function per method |
| A class used as a dependency (`Depends()` with no argument) | A function that returns a dataclass |
| Settings read from a module global everywhere | `get_settings()` / `SettingsDep`, so tests can override |
| Live network calls in unit tests | A dependency override with `httpx.MockTransport` |
| Mocking the database in integration tests | A real test database |
| `async_asgi_testclient` | `httpx.AsyncClient` with `ASGITransport` |
| `FastAPI(root_path=...)` or `openapi_prefix` | `fastapi run --root-path` |
| Iterating or mutating `router.routes` | `iter_route_contexts()` |
| `print` | `logging` |
| Unbounded strings, lists, or list endpoints | `max_length` limits and a paginated `limit` with `le=100` |
| `allow_origins=["*"]` with credentials | An explicit origin list |
| `create_all()` in production, or migrations at app startup | A numbered SQL file in `migrations/`, run by the `migrate` release step |
| Editing, renaming or deleting a migration that has run | A new numbered file that makes the change |
| A model change with no migration, or a migration with no model change | Both in the same change, matching column for column |
| A new table without row level security | `ALTER TABLE … ENABLE ROW LEVEL SECURITY` in the same file |

---

## 20. Coming from Django or Spring

| Django / DRF | Spring Boot | FastAPI |
|---|---|---|
| `urls.py` + views | `@RestController` + `@GetMapping` | `APIRouter` + `@router.get` path operations |
| DRF serializers | DTOs + Bean Validation (`@Valid`) | Pydantic models (`FoodCreate`, `FoodPublic`) |
| `settings.py` | `application.yml` + `@ConfigurationProperties` | pydantic-settings `BaseSettings` + `get_settings()` |
| Middleware, DRF permission classes | Filters, Spring Security | Middleware for cross-cutting HTTP concerns; dependencies for auth and permissions |
| No built-in DI | `@Autowired`, `@Bean` | `Depends()`: per request, cached, overridable in tests |
| `transaction.atomic`, `ATOMIC_REQUESTS` | `@Transactional` | A `yield` session dependency + an explicit `commit()` |
| `get_object_or_404`, custom exception handlers | `@ControllerAdvice`, `@ExceptionHandler` | Validate-and-load dependencies + `@app.exception_handler` |
| Django ORM | JPA / Hibernate | SQLModel or SQLAlchemy 2.0 |
| `makemigrations` / `migrate` | Flyway / Liquibase | Numbered SQL files run by `migrations/migrate.py` (Alembic in most FastAPI projects) |
| `AppConfig.ready()` | `ApplicationRunner`, `@PostConstruct` | `lifespan` |
| `APITestCase`, test client | `MockMvc` + `@MockBean` | `TestClient` + `app.dependency_overrides` |
| drf-spectacular | springdoc-openapi | Built in: `/docs`, `/openapi.json` |
| Celery | `@Async`, Spring Batch | `BackgroundTasks` for tiny work, Celery, Arq or RQ otherwise |

- **No thread-local request context.** Everything a handler needs arrives as a typed parameter.
- **Sync vs async is a per-function choice with real consequences** (§4). Blocking code, the default habit in Django and Spring, is fine only in `def` functions.
- **Validation is declared in type annotations,** and the same types generate the OpenAPI docs and client SDKs.

---

## 21. Pre-Merge Checklist

- [ ] No blocking calls in `async def`, and the `ASYNC` rules are clean.
- [ ] Every parameter and dependency uses `Annotated`, with no `...` defaults.
- [ ] Every route has a return type or `response_model`, and no table model leaks.
- [ ] Inputs are bounded and list endpoints are paginated.
- [ ] Domain errors map to the shared envelope with a stable `code`.
- [ ] Writes are committed before the route returns.
- [ ] The acting user comes from the token, and ownership is checked.
- [ ] Each schema change is the next `NNNN_slug.sql` file, matches the SQLModel models, and enables RLS on new tables. No migration that has run was edited.
- [ ] Tests make no network calls, clear their overrides, and integration tests use a real database.
- [ ] `ruff check`, `ruff format --check`, `ty check` and `pytest` all pass.
- [ ] No secrets or `.env` files are committed.

---

## Source Index

- **Official FastAPI agent skill** — the `fastapi/.agents/skills/fastapi/` folder in [fastapi/fastapi](https://github.com/fastapi/fastapi/tree/master/fastapi/.agents/skills/fastapi): `SKILL.md` plus the `dependencies`, `path-operations`, `pydantic`, `responses`, `streaming` and `other-tools` references. It's listed at [skills.sh/fastapi](https://skills.sh/fastapi) and ships in the wheel. It contributed `Annotated`, return types, router configuration, the async defaults, streaming, `app.frontend()`, OpenTelemetry, and the tooling picks.
- **[zhanymkanov/fastapi-best-practices](https://github.com/zhanymkanov/fastapi-best-practices)** — `README.md` and `AGENTS.md`. It contributed the domain structure, async rules, Pydantic usage, validate-and-load and chained dependencies, DB naming and SQL-first, Alembic conventions, background tasks, testing, and the anti-pattern list.
- **[fastapi/full-stack-fastapi-template](https://github.com/fastapi/full-stack-fastapi-template)** — `backend/`: `pyproject.toml`, `app/main.py`, `app/api/deps.py`, `app/core/config.py`, `app/core/security.py`, `app/models.py`, `app/api/routes/items.py`, `tests/conftest.py`, the `Dockerfile` and the `test-backend.yml` workflow. It's the working reference for SQLModel models, settings validation, pwdlib and PyJWT, tooling, Docker and CI.
- **[fulit103/fastapi-clean](https://github.com/fulit103/fastapi-clean)** (in Spanish) — `SKILL.md`, `references/error_handling.md` and `references/testing.md`. It contributed layering only where it pays off, domain exceptions mapped by handlers, Protocol fakes, the three test levels, and API-key hashing.
- **FastAPI docs and release notes** ([fastapi.tiangolo.com](https://fastapi.tiangolo.com)) — the custom-response (JSON performance), events, settings, testing, async-tests, OAuth2-JWT and its source, behind-a-proxy, Docker, server-workers, handling-errors, dependencies-with-yield, query-param-models, sql-databases and fastapi-cli pages, plus [release notes](https://fastapi.tiangolo.com/release-notes/) 0.125 through 0.162.
- **[DEV: FastAPI Production Best Practices (2026)](https://dev.to/akaranjkar08/fastapi-production-best-practices-build-bulletproof-python-apis-2026-3d68)** — the error envelope with a request ID, composable auth and pagination dependencies, and logging background-task failures. The article mentions rate limiting but doesn't implement it.
- **neversight `fastapi-best-practices`** ([skills.sh](https://skills.sh/neversight/learn-skills.dev/fastapi-best-practices)) — couldn't be read. The page was rate-limited, and the source repo is too large for the GitHub listing API. Its stated scope matches the sections of zhanymkanov's guide one for one, which suggests it's derived from that guide.
- **[fastapi-to-skill](https://pypi.org/project/fastapi-to-skill/)** — out of scope here. It generates a CLI and a skill from an existing app, which will be useful once the API exists.
