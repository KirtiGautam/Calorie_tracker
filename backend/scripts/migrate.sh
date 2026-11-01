#!/usr/bin/env bash
# Runs the pending SQL migrations against the database in DATABASE_URL (read from .env).
# `docker compose up --build` already does this before starting the API. Use this to
# migrate without starting it.
set -euo pipefail
cd "$(dirname "$0")/.."

exec docker compose run --rm --build migrate
