# syntax=docker/dockerfile:1
ARG PYTHON_VERSION=3.14

# ---- builder: resolve and install dependencies into /app/.venv ----
FROM python:${PYTHON_VERSION}-slim AS builder
COPY --from=ghcr.io/astral-sh/uv:0.11.29 /uv /bin/uv

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=0 \
    UV_NO_DEV=1
WORKDIR /app

RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen --no-install-project --no-dev

# ---- dev: every dependency, including the dev group, for lint and tests ----
# The source isn't copied in: compose bind-mounts the backend folder at /app, so edits
# show up without a rebuild. The venv lives in /opt/venv so the mount can't hide it.
# Rebuild only when pyproject.toml or uv.lock change.
FROM python:${PYTHON_VERSION}-slim AS dev
COPY --from=ghcr.io/astral-sh/uv:0.11.29 /uv /bin/uv

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=0 \
    UV_PROJECT_ENVIRONMENT=/opt/venv \
    UV_NO_SYNC=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    GRAMWISE_IN_DOCKER=1
WORKDIR /app

RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen --no-install-project

# ---- runtime: only the interpreter, the venv, the app code and the migrations ----
# Keep this stage last, so a plain `docker build .` produces the production image.
FROM python:${PYTHON_VERSION}-slim AS runtime

# pip isn't needed at runtime, and dropping it shrinks the image and the attack surface.
RUN python -m pip uninstall --yes --quiet pip \
    && groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    FASTAPI_ENV=production
WORKDIR /app

COPY --from=builder /app/.venv /app/.venv
COPY app ./app
# The migrate service in compose.yaml runs migrations/migrate.py from this same image.
COPY migrations ./migrations

USER app
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import urllib.request, sys; sys.exit(urllib.request.urlopen('http://127.0.0.1:8000/health/ready', timeout=2).status != 200)"]

# Plain uvicorn instead of `fastapi run`: the FastAPI CLI and the rest of fastapi[standard]
# are dev-only, which keeps them out of the image. uvloop and httptools are picked up automatically.
# One process per container. Scale with replicas, or append "--workers", "N" on a single host.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--no-server-header"]
