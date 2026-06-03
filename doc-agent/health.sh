#!/bin/bash
# health.sh — Quick liveness check for the doc-agent.
curl -sf http://localhost:${PORT:-8893}/health >/dev/null 2>&1 && echo "ok" || echo "down"
