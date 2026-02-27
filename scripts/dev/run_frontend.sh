#!/usr/bin/env bash
# Photo Coach Pro — Run Frontend (dev)
# Name: Jason E Alaounis | Email: Philotimo71@gmail.com | Company: ALÁON

set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FRONTEND_DIR="$REPO_ROOT/frontend"

echo "==> Repo: $REPO_ROOT"
echo "==> Frontend: $FRONTEND_DIR"

cd "$FRONTEND_DIR"

# Prefer pnpm if available, else npm
if command -v pnpm >/dev/null 2>&1; then
  echo "==> Using pnpm"
  pnpm install
  exec pnpm dev
else
  echo "==> Using npm"
  npm install
  exec npm run dev
fi