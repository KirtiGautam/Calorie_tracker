#!/usr/bin/env bash
# Runs db/bootstrap.sql against the Supabase database in DATABASE_URL (read from .env), with psql
# from the official Postgres image, so nothing needs installing on the host. The compose
# `bootstrap` service reads .env the same way the api and migrate services do.
set -euo pipefail
cd "$(dirname "$0")/.."

exec docker compose run --rm -T bootstrap < db/bootstrap.sql
