#!/bin/bash
# stop.sh — Stop the running doc-agent process inside the container.
set -euo pipefail

if pkill -f '[u]vicorn server:app' 2>/dev/null; then
    echo -e "\033[32m[ OK ]\033[0m  Doc agent stopped."
else
    echo -e "\033[33m[WARN]\033[0m  No running doc-agent server found."
fi
