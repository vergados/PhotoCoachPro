#!/usr/bin/env bash
# Photo Coach Pro — Dev Up (backend + frontend)
# Name: Jason E Alaounis | Email: Philotimo71@gmail.com | Company: ALÁON

set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_DIR="$REPO_ROOT/.run"
BACKEND_PID_FILE="$RUN_DIR/backend.pid"
FRONTEND_PID_FILE="$RUN_DIR/frontend.pid"
BACKEND_LOG="$RUN_DIR/backend.log"
FRONTEND_LOG="$RUN_DIR/frontend.log"

mkdir -p "$RUN_DIR"

print_instructions() {
  echo ""
  echo "=== Photo Coach Pro Dev Up ==="
  echo "Recommended (2 terminals):"
  echo ""
  echo "Terminal 1 (backend):"
  echo "  bash \"$REPO_ROOT/scripts/dev/run_backend.sh\""
  echo ""
  echo "Terminal 2 (frontend):"
  echo "  bash \"$REPO_ROOT/scripts/dev/run_frontend.sh\""
  echo ""
  echo "Optional: run both in background:"
  echo "  bash \"$REPO_ROOT/scripts/dev/dev_up.sh\" --bg"
  echo ""
}

is_running_pidfile() {
  local pidfile="$1"
  [[ -f "$pidfile" ]] || return 1
  local pid
  pid="$(cat "$pidfile" 2>/dev/null || true)"
  [[ -n "${pid:-}" ]] || return 1
  kill -0 "$pid" >/dev/null 2>&1
}

start_bg() {
  if is_running_pidfile "$BACKEND_PID_FILE"; then
    echo "✅ Backend already running (pid $(cat "$BACKEND_PID_FILE"))."
  else
    echo "==> Starting backend in background..."
    nohup bash "$REPO_ROOT/scripts/dev/run_backend.sh" >"$BACKEND_LOG" 2>&1 &
    echo $! > "$BACKEND_PID_FILE"
    echo "   Backend PID: $(cat "$BACKEND_PID_FILE")"
    echo "   Log: $BACKEND_LOG"
  fi

  if is_running_pidfile "$FRONTEND_PID_FILE"; then
    echo "✅ Frontend already running (pid $(cat "$FRONTEND_PID_FILE"))."
  else
    echo "==> Starting frontend in background..."
    nohup bash "$REPO_ROOT/scripts/dev/run_frontend.sh" >"$FRONTEND_LOG" 2>&1 &
    echo $! > "$FRONTEND_PID_FILE"
    echo "   Frontend PID: $(cat "$FRONTEND_PID_FILE")"
    echo "   Log: $FRONTEND_LOG"
  fi

  echo ""
  echo "Open:"
  echo "  Frontend: http://localhost:3000"
  echo "  Backend health: http://127.0.0.1:8000/health"
  echo ""
  echo "To stop (we’ll add dev_down.sh next):"
  echo "  kill \$(cat \"$BACKEND_PID_FILE\") \$(cat \"$FRONTEND_PID_FILE\")"
}

case "${1:-}" in
  "" )
    print_instructions
    ;;
  "--bg" )
    start_bg
    ;;
  * )
    echo "Unknown option: $1"
    print_instructions
    exit 2
    ;;
esac