#!/usr/bin/env bash
# Push local `backend/` to GitHub repo that Render deploys (adoreventure-backend-clean).
# Run from project root after committing backend changes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

REMOTE_NAME="${RENDER_BACKEND_REMOTE:-backend-clean}"
BRANCH_EXPORT="backend-clean-export"
TARGET_BRANCH="${RENDER_BACKEND_BRANCH:-main}"

if [ ! -d backend ]; then
  echo "❌ backend/ not found. Run from AdoreVenture project root."
  exit 1
fi

if ! git remote get-url "$REMOTE_NAME" &>/dev/null; then
  echo "❌ Git remote '$REMOTE_NAME' is not configured."
  echo "   Add it once:"
  echo "   git remote add $REMOTE_NAME https://github.com/DagmawiMulualem/adoreventure-backend-clean.git"
  exit 1
fi

echo "📦 Splitting subtree backend/ → branch $BRANCH_EXPORT ..."
git subtree split --prefix=backend -b "$BRANCH_EXPORT"

echo "🚀 Pushing $BRANCH_EXPORT → $REMOTE_NAME/$TARGET_BRANCH ..."
# Render tracks this repo; history may diverge — use force when replacing deploy source.
git push "$REMOTE_NAME" "$BRANCH_EXPORT:$TARGET_BRANCH" --force

echo "✅ Done. Render should auto-deploy from adoreventure-backend-clean ($TARGET_BRANCH)."
