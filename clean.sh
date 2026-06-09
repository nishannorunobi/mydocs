#!/bin/bash
# clean.sh — Stop Plane stack. Data volumes are preserved. Use destroy.sh to also wipe all data.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BOLD="\033[1m"; GREEN="\033[32m"; CYAN="\033[36m"; YELLOW="\033[33m"; RESET="\033[0m"
ok()   { echo -e "${GREEN}[ OK ]${RESET}  $*"; }
info() { echo -e "${CYAN}[INFO]${RESET}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET}  $*"; }

echo -e "\n${BOLD}╔══════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║   Mydocs — Clean                         ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${RESET}\n"

# Stop stack
info "Stopping Plane stack..."
docker compose down
ok "Stack stopped."

echo ""
warn "Data volumes preserved — run ${BOLD}./destroy.sh${RESET} to also wipe all Plane data."
echo -e "\n${GREEN}Clean complete.${RESET} Run ${BOLD}./start.sh${RESET} to restart.\n"
