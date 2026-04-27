#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

if [[ "$#" -eq 0 ]]; then
  echo "No Vercel path filters were provided; continuing build."
  exit 1
fi

HEAD_SHA="${VERCEL_GIT_COMMIT_SHA:-HEAD}"
PREVIOUS_SHA="${VERCEL_GIT_PREVIOUS_SHA:-}"
ZERO_SHA="0000000000000000000000000000000000000000"

if [[ -n "$PREVIOUS_SHA" && "$PREVIOUS_SHA" != "$ZERO_SHA" ]]; then
  DIFF_RANGE=("$PREVIOUS_SHA" "$HEAD_SHA")
elif git rev-parse --verify HEAD^ >/dev/null 2>&1; then
  DIFF_RANGE=("HEAD^" "HEAD")
else
  echo "No previous commit found; continuing build."
  exit 1
fi

COMMON_PATHS=(
  "package.json"
  "pnpm-lock.yaml"
  "pnpm-workspace.yaml"
  "turbo.json"
  "scripts/vercel-ignore.sh"
)

if git diff --quiet "${DIFF_RANGE[@]}" -- "$@" "${COMMON_PATHS[@]}"; then
  echo "No Vercel-relevant changes for: $*"
  exit 0
fi

echo "Detected Vercel-relevant changes for: $*"
exit 1
