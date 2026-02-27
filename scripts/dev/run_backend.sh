#!/usr/bin/env bash
# Photo Coach Pro — Run Backend (dev)
# Name: Jason E Alaounis | Email: Philotimo71@gmail.com | Company: ALÁON

set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKEND_DIR="$REPO_ROOT/backend"
PYTHON_BIN="${PYTHON_BIN:-python3}"

echo "==> Repo: $REPO_ROOT"
echo "==> Backend: $BACKEND_DIR"

cd "$BACKEND_DIR"

# Create venv if missing
if [[ ! -d ".venv" ]]; then
  echo "==> Creating backend venv..."
  "$PYTHON_BIN" -m venv .venv
fi

source ".venv/bin/activate"

echo "==> Installing backend deps..."
pip install -U pip
pip install -r requirements.txt

# Make backend + core importable in repo mode
export PYTHONPATH="$REPO_ROOT/backend/src:$REPO_ROOT/core/src:${PYTHONPATH:-}"

echo "==> Starting FastAPI (uvicorn)..."
echo "    URL: http://127.0.0.1:8000"
echo "    Health: http://127.0.0.1:8000/health"
exec uvicorn photo_coach_api.main:app --reload --host 127.0.0.1 --port 8000