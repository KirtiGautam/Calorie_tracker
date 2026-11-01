#!/usr/bin/env bash
# ruff check, ruff format --check and ty check, inside the dev container.
set -euo pipefail
source "$(dirname "$0")/_docker.sh"
cd "$(dirname "$0")/.."

uv run ruff check .
uv run ruff format --check .
uv run ty check
