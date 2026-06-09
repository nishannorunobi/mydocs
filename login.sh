#!/bin/bash
# Open a shell inside a Plane container. Usage: ./login.sh [service]
# Default service: plane-api. Others: plane-worker, plane-web, plane-proxy
set -euo pipefail
SERVICE="${1:-plane-api}"
docker exec -it "$SERVICE" sh
