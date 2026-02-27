#!/usr/bin/env bash
# Photo Coach Pro — Test Critique Endpoint (dev)
# Name: Jason E Alaounis | Email: Philotimo71@gmail.com | Company: ALÁON

set -euo pipefail
IFS=$'\n\t'

IMAGE_PATH="${1:-}"
API_URL="${2:-http://127.0.0.1:8000/api/v1/critique}"

if [[ -z "$IMAGE_PATH" ]]; then
  echo "Usage:"
  echo "  $0 /path/to/photo.jpg [api_url]"
  echo ""
  echo "Example:"
  echo "  $0 \"$HOME/Pictures/test.jpg\""
  exit 2
fi

if [[ ! -f "$IMAGE_PATH" ]]; then
  echo "❌ Image not found: $IMAGE_PATH"
  exit 2
fi

echo "==> Posting image to: $API_URL"
echo "==> Image: $IMAGE_PATH"

curl -sS \
  -X POST \
  -F "file=@${IMAGE_PATH}" \
  "$API_URL" | python3 -m json.tool

echo "✅ Critique request completed."