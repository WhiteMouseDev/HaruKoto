#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage:
  DATABASE_URL="postgresql+asyncpg://..." pnpm seed:learning
  DATABASE_URL="postgresql+asyncpg://..." PRISMA_DATABASE_URL="postgresql://..." pnpm seed:learning

Options:
  --dry-run  Print the seed plan without connecting to the database.
  -h, --help Show this help message.

This command seeds learning content in dependency order:
  1. Prisma static content: vocabulary, grammar, kana, cloze, sentence arrange, scenarios, characters
  2. SQLAlchemy lesson content: N5 chapters, lessons, lesson item links
  3. SQLAlchemy study stages: N5 vocabulary, grammar, sentence stages
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --)
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is required for API seed commands." >&2
  echo "Expected SQLAlchemy async URL, for example: postgresql+asyncpg://user:pass@host:5432/db" >&2
  exit 2
fi

API_DATABASE_URL="$DATABASE_URL"
PRISMA_DATABASE_URL="${PRISMA_DATABASE_URL:-${API_DATABASE_URL/postgresql+asyncpg:/postgresql:}}"

driver_for() {
  local url="$1"
  printf '%s\n' "${url%%://*}"
}

run_prisma_seed() {
  echo "==> Prisma static content seed (DATABASE_URL driver: $(driver_for "$PRISMA_DATABASE_URL"))"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "+ pnpm --filter @harukoto/database db:seed"
    return
  fi

  (cd "$ROOT_DIR" && DATABASE_URL="$PRISMA_DATABASE_URL" pnpm --filter @harukoto/database db:seed)
}

run_api_seed() {
  local module="$1"
  local label="$2"

  echo "==> $label (DATABASE_URL driver: $(driver_for "$API_DATABASE_URL"))"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "+ cd apps/api && uv run python -m $module"
    return
  fi

  (cd "$ROOT_DIR/apps/api" && DATABASE_URL="$API_DATABASE_URL" uv run python -m "$module")
}

run_prisma_seed
run_api_seed "app.seeds.lessons" "SQLAlchemy lesson seed"
run_api_seed "app.seeds.study_stages" "SQLAlchemy study stage seed"

echo "Learning content seed complete."
