#!/bin/bash
# SessionStart hook: 세션 시작 시 프로젝트 컨텍스트 자동 주입

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

cd "$PROJECT_DIR" || exit 0

BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
UPSTREAM=$(git rev-parse --abbrev-ref @{upstream} 2>/dev/null || echo "no upstream")
AHEAD_BEHIND=$(git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null | awk '{print "ahead:"$1" behind:"$2}' || echo "")
DIRTY=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
RECENT=$(git log --oneline -3 2>/dev/null || echo "no commits")

# 변경된 앱 영역 감지
CHANGED_AREAS=""
CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null; git diff --cached --name-only 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null)
echo "$CHANGED_FILES" | grep -q "^apps/admin/" && CHANGED_AREAS="${CHANGED_AREAS} admin"
echo "$CHANGED_FILES" | grep -q "^apps/web/" && CHANGED_AREAS="${CHANGED_AREAS} web"
echo "$CHANGED_FILES" | grep -q "^apps/landing/" && CHANGED_AREAS="${CHANGED_AREAS} landing"
echo "$CHANGED_FILES" | grep -q "^apps/mobile/" && CHANGED_AREAS="${CHANGED_AREAS} mobile"
echo "$CHANGED_FILES" | grep -q "^apps/api/" && CHANGED_AREAS="${CHANGED_AREAS} api"
echo "$CHANGED_FILES" | grep -q "^packages/" && CHANGED_AREAS="${CHANGED_AREAS} packages"

MSG="[Branch] ${BRANCH} → ${UPSTREAM} ${AHEAD_BEHIND}
[Dirty] ${DIRTY} files
[Recent]
${RECENT}"

if [ -n "$CHANGED_AREAS" ]; then
  MSG="${MSG}
[Active areas]${CHANGED_AREAS}"
fi

# Escalation scan — surface any unresolved decisions from prior sessions.
# Filters by `status: open` in the frontmatter; ignores README/resolved/.
ESCALATION_DIR=".planning/escalations"
if [ -d "$ESCALATION_DIR" ]; then
  OPEN_ESCALATIONS=$(find "$ESCALATION_DIR" -maxdepth 1 -type f -name "*.md" ! -name "README.md" 2>/dev/null | \
    while IFS= read -r f; do
      if grep -q "^status: open" "$f" 2>/dev/null; then
        slug=$(basename "$f" .md)
        severity=$(grep -E "^severity:" "$f" | head -1 | sed 's/severity:[[:space:]]*//')
        echo "  • [${severity:-warn}] ${slug}"
      fi
    done)
  if [ -n "$OPEN_ESCALATIONS" ]; then
    MSG="${MSG}
[Escalations — awaiting user decision]
${OPEN_ESCALATIONS}
  → review files in .planning/escalations/ and add a ## Resolution section, then set status: resolved"
  fi
fi

jq -Rn --arg msg "$MSG" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $msg
  }
}'
