#!/usr/bin/env bash
# Photo Coach Pro — Dev Down (stop background dev_up --bg)
# Name: Jason E Alaounis | Email: Philotimo71@gmail.com | Company: ALÁON

set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_DIR="$REPO_ROOT/.run"
BACKEND_PID_FILE="$RUN_DIR/backend.pid"
FRONTEND_PID_FILE="$RUN_DIR/frontend.pid"

stop_pidfile() {
  local pidfile="$1"
  local name="$2"

  if [[ ! -f "$pidfile" ]]; then
    echo "ℹ️  No $name pidfile found."
    return 0
  fi

  local pid
  pid="$(cat "$pidfile" 2>/dev/null || true)"

  if [[ -z "${pid:-}" ]]; then
    echo "ℹ️  Empty pidfile for $name."
    rm -f "$pidfile"
    return 0
  fi

  if kill -0 "$pid" >/dev/null 2>&1; then
    echo "==> Stopping $name (PID $pid)..."
    kill "$pid" || true
  else
    echo "ℹ️  $name not running (PID $pid not alive)."
  fi

  rm -f "$pidfile"
}

stop_pidfile "$BACKEND_PID_FILE" "backend"
stop_pidfile "$FRONTEND_PID_FILE" "frontend"

echo "✅ Dev processes stopped."