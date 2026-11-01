#!/usr/bin/env bash
# Runs db/bootstrap.sql against the Supabase database in DATABASE_URL (read from .env),
# with psql from the official Postgres image, so nothing needs installing on the host.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

: "${DATABASE_URL:?DATABASE_URL is not set. Copy .env.example to .env and fill it in.}"

docker run --rm -i -e DATABASE_URL postgres:17-alpine \
  sh -c 'psql "$DATABASE_URL" --no-psqlrc --set ON_ERROR_STOP=1 --file -' < db/bootstrap.sql
