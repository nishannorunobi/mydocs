#!/bin/bash
# start.sh — Build (if needed) and start all Plane services.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; BOLD="\033[1m"; RESET="\033[0m"

[ -f ".env" ] || { echo -e "${RED}[ERROR]${RESET} .env not found."; exit 1; }

source .env

# Build doc-agent image if it doesn't exist or --build flag passed
if [[ "${1:-}" == "--build" ]] || ! docker image inspect plane-doc-agent:latest &>/dev/null; then
    echo -e "${BOLD}==> Building doc-agent image...${RESET}"
    docker compose build plane-doc-agent
    echo -e "${GREEN}    Image built.${RESET}"
fi

echo -e "${BOLD}==> Starting Plane...${RESET}"
docker compose up -d

echo ""
echo -e "${GREEN}${BOLD}==> Plane is starting (allow ~30s for first boot)${RESET}"
echo -e "    App      : ${BOLD}http://localhost:${PLANE_PORT:-80}${RESET}"
echo -e "    MinIO UI : ${BOLD}http://localhost:9090${RESET}"
echo -e "    Doc Agent: ${BOLD}http://localhost:8893${RESET}"
echo ""
echo -e "    ${BOLD}./logs.sh${RESET}              — tail all logs"
echo -e "    ${BOLD}./logs.sh plane-api${RESET}    — tail API logs"
echo -e "    ${BOLD}./logs.sh plane-worker${RESET} — tail worker logs"
echo -e "    ${BOLD}./status.sh${RESET}            — container status"
echo -e "    ${BOLD}./stop.sh${RESET}              — stop (data preserved)"
echo -e "    ${BOLD}./destroy.sh${RESET}           — stop + wipe all data"
