#!/usr/bin/env bash
# pytest with a 90% coverage gate, inside the dev container. No network or database needed.
# Extra arguments go to pytest, for example: ./scripts/test.sh -k goal
set -euo pipefail
source "$(dirname "$0")/_docker.sh"
cd "$(dirname "$0")/.."

uv run coverage run -m pytest "$@"
uv run coverage report --show-missing --fail-under=90
