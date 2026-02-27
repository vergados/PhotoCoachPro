#!/usr/bin/env bash
# Photo Coach Pro — Test Backend Health (dev)
# Name: Jason E Alaounis | Email: Philotimo71@gmail.com | Company: ALÁON

set -euo pipefail
IFS=$'\n\t'

URL="${1:-http://127.0.0.1:8000/health}"

echo "==> Checking: $URL"

if command -v curl >/dev/null 2>&1; then
  curl -sS "$URL" | python3 -m json.tool
else
  echo "curl not found. Install curl or run this check in a browser."
  exit 1
fi

echo "✅ Health check completed."