#!/bin/bash

# ── Mirror logging ─────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/init/create_logging_path.sh" ]; then
    source "$_WS_ROOT/init/create_logging_path.sh"
    setup_logging
fi
# ──────────────────────────────────────────────────────────────────────────────
# logs.sh — Tail logs for all Plane services (or a specific one).
# Usage:
#   ./logs.sh            → tail all services
#   ./logs.sh api        → tail only the API
#   ./logs.sh worker     → tail only the worker
#   ./logs.sh web        → tail only the frontend

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SERVICE="${1:-}"

if [ -n "$SERVICE" ]; then
    docker compose logs -f --tail=100 "$SERVICE"
else
    docker compose logs -f --tail=50
fi
