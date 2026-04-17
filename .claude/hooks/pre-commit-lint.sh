#!/bin/bash
# Pre-commit lint hook: 변경된 앱에 맞는 lint를 자동 실행
# git commit 명령 감지 시 실행됨

set -euo pipefail

CMD=$(jq -r '.tool_input.command // ""' 2>/dev/null)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

# git commit이 아니면 패스
if ! echo "$CMD" | grep -q "git commit"; then
  exit 0
fi

cd "$PROJECT_DIR" || exit 0

CHANGED=$(git diff --cached --name-only 2>/dev/null)
if [ -z "$CHANGED" ]; then
  CHANGED=$(git diff --name-only HEAD 2>/dev/null)
fi
if [ -z "$CHANGED" ]; then exit 0; fi

ERRORS=0
MESSAGES=""

# Mobile 변경 감지
if echo "$CHANGED" | grep -q "^apps/mobile/"; then
  cd apps/mobile
  if ! dart format --set-exit-if-changed lib/ test/ > /dev/null 2>&1; then
    dart format lib/ test/ > /dev/null 2>&1
    MESSAGES="${MESSAGES}[mobile] dart format 자동 수정 완료\n"
  fi
  ANALYZE_OUT=$(flutter analyze 2>&1 | tail -3)
  if echo "$ANALYZE_OUT" | grep -q "error"; then
    ERRORS=1
    MESSAGES="${MESSAGES}[mobile] flutter analyze 에러 발견\n"
  fi
  cd ../..
fi

# Backend 변경 감지
if echo "$CHANGED" | grep -q "^apps/api/"; then
  cd apps/api
  if ! uv run ruff format --check app/ tests/ > /dev/null 2>&1; then
    uv run ruff format app/ tests/ > /dev/null 2>&1
    MESSAGES="${MESSAGES}[api] ruff format 자동 수정 완료\n"
  fi
  if ! uv run ruff check app/ tests/ > /dev/null 2>&1; then
    ERRORS=1
    MESSAGES="${MESSAGES}[api] ruff check 에러 발견\n"
  fi
  cd ../..
fi

# Web/Admin/Landing/Packages 변경 감지
if echo "$CHANGED" | grep -qE "^(apps/admin/|apps/web/|apps/landing/|packages/)"; then
  LINT_OUT=$(pnpm lint 2>&1)
  if [ $? -ne 0 ]; then
    ERRORS=1
    MESSAGES="${MESSAGES}[frontend] pnpm lint 에러 발견\n"
  fi
fi

if [ $ERRORS -ne 0 ]; then
  jq -Rn --arg reason "Lint 실패:\n${MESSAGES}수정 후 다시 커밋하세요" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
fi

if [ -n "$MESSAGES" ]; then
  jq -Rn --arg reason "${MESSAGES}변경 사항을 git add 후 다시 커밋하세요" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
fi
