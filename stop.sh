#!/bin/bash
# stop.sh — Stop Plane (data is preserved in Docker volumes).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GREEN="\033[32m"; YELLOW="\033[33m"; BOLD="\033[1m"; RESET="\033[0m"

echo -e "${YELLOW}==> Stopping Plane...${RESET}"
docker compose down
echo -e "${GREEN}    Plane stopped. Data is preserved in Docker volumes.${RESET}"
echo -e "    Run ${BOLD}./start.sh${RESET} to bring it back up."
