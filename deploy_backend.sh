#!/bin/bash
# Deploy Python API → GitHub repo that Render uses (adoreventure-backend-clean).
# See also: BACKEND_REPOS.md

set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [ ! -x "./push_backend_render.sh" ]; then
  echo "❌ push_backend_render.sh not found or not executable."
  exit 1
fi

echo "🚀 Deploying backend/ → adoreventure-backend-clean (Render)..."
exec ./push_backend_render.sh
