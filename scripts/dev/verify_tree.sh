#!/usr/bin/env bash
# Photo Coach Pro — Verify Repo Tree (dev)
# Name: Jason E Alaounis | Email: Philotimo71@gmail.com | Company: ALÁON

set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

need() {
  local p="$1"
  if [[ ! -e "$REPO_ROOT/$p" ]]; then
    echo "❌ Missing: $p"
    exit 1
  else
    echo "✅ Found:  $p"
  fi
}

echo "==> Repo: $REPO_ROOT"
echo ""

need "backend/src/photo_coach_api/main.py"
need "backend/src/photo_coach_api/api/__init__.py"
need "backend/src/photo_coach_api/api/routes_health.py"
need "backend/src/photo_coach_api/api/routes_critique.py"
need "backend/src/photo_coach_api/services/critique_service.py"

need "core/src/photo_coach_core/__init__.py"
need "core/src/photo_coach_core/io/exif.py"
need "core/src/photo_coach_core/critique/exposure.py"
need "core/src/photo_coach_core/critique/sharpness.py"
need "core/src/photo_coach_core/critique/color.py"
need "core/src/photo_coach_core/scoring/aggregate.py"
need "core/src/photo_coach_core/print/dpi.py"

need "frontend/package.json"
need "frontend/next.config.js"
need "frontend/postcss.config.js"
need "frontend/tailwind.config.js"
need "frontend/tsconfig.json"
need "frontend/next-env.d.ts"
need "frontend/src/app/layout.tsx"
need "frontend/src/app/page.tsx"
need "frontend/src/app/globals.css"

echo ""
echo "✅ Tree looks good."