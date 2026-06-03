#!/bin/bash
# status.sh — Show running status and ports for all Plane containers.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BOLD="\033[1m"; RESET="\033[0m"

echo -e "${BOLD}==> Plane container status${RESET}"
docker compose ps

echo ""
echo -e "${BOLD}==> Ports${RESET}"
docker compose port plane-proxy 80 2>/dev/null && true
