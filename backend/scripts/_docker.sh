# Sourced by the scripts in this folder. Re-runs the calling script inside the dev
# container unless it's already there, so the host only needs Docker.
if [[ "${GRAMWISE_IN_DOCKER:-}" != "1" ]]; then
  cd "$(dirname "$0")/.."
  exec docker compose run --rm --build dev "./scripts/$(basename "$0")" "$@"
fi
