#!/bin/sh
# build.sh — Install Python 3, create venv, and install doc-agent dependencies.
# Run INSIDE plane-aio container (Alpine Linux).
# NOTE: install in two batches to avoid OOM — pip resolving all deps at once is too heavy.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ── Install Python 3 if missing ───────────────────────────────────────────────
if ! command -v python3 >/dev/null 2>&1; then
    echo "[INFO] Installing Python 3..."
    apk add --no-cache python3 py3-pip
    echo "[ OK ] Python 3 installed."
else
    echo "[ OK ] Python 3 found: $(python3 --version)"
fi

# ── Create virtual environment ────────────────────────────────────────────────
if [ ! -d ".venv" ]; then
    echo "[INFO] Creating virtual environment..."
    python3 -m venv .venv
    echo "[ OK ] venv created."
fi

# ── Upgrade pip ───────────────────────────────────────────────────────────────
.venv/bin/pip install --quiet --no-cache-dir --upgrade pip

# ── Batch 1: lightweight web framework packages ───────────────────────────────
echo "[INFO] Installing web framework packages..."
.venv/bin/pip install --quiet --no-cache-dir fastapi "uvicorn[standard]" python-dotenv
echo "[ OK ] Web framework installed."

# ── Batch 2: anthropic SDK + requests (pydantic already present) ──────────────
echo "[INFO] Installing anthropic SDK..."
.venv/bin/pip install --quiet --no-cache-dir anthropic requests
echo "[ OK ] Anthropic SDK installed."

# ── Create agent.conf if missing ──────────────────────────────────────────────
if [ ! -f "agent.conf" ]; then
    cp agent.conf.example agent.conf
    echo "[ACTION REQUIRED] Edit agent.conf and set your ANTHROPIC_API_KEY"
else
    echo "[ OK ] agent.conf exists."
fi

# ── Create memory directory ───────────────────────────────────────────────────
mkdir -p memory
echo "[ OK ] memory/ directory ready."
echo ""
echo "[ OK ] Build complete."
