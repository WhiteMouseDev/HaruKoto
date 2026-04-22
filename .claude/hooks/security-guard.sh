#!/usr/bin/env bash
# Security guard — blocks writes to secret-bearing paths.
#
# Fires on PreToolUse for Edit|Write|MultiEdit. Reads Claude Code's hook JSON
# from stdin and rejects (exit 2) if the target path matches any sensitive
# pattern. This is a last-line deterministic guard — it runs in ms and costs
# no tokens, so even if an agent hallucinates past prose rules it still can't
# commit secrets.
#
# Safe to fail open on parse errors: we'd rather have a non-blocking hook
# than a broken workflow, and jq/Python are always present in this project.

set -euo pipefail

INPUT=$(cat)

# Extract the file path from the tool input. tool_input.file_path works for
# Write/Edit/MultiEdit. If no path, exit 0 (not our concern).
FILE_PATH=$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    ti = data.get("tool_input") or {}
    path = ti.get("file_path") or ""
    print(path)
except Exception:
    pass
' 2>/dev/null || true)

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Normalize: strip leading ./ and project dir prefix for matching convenience.
NORMALIZED="${FILE_PATH#./}"
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  NORMALIZED="${NORMALIZED#${CLAUDE_PROJECT_DIR}/}"
fi

# Whitelist — template/example files that are safe to commit even though
# they share a prefix with secret files.
SAFE_SUFFIX_RE='\.(example|template|sample|dist)$'

if printf '%s' "$NORMALIZED" | grep -Eq "$SAFE_SUFFIX_RE"; then
  exit 0
fi

# Forbidden patterns — one regex per line. These are DENY rules; any match
# blocks the write.
#
# Rationale per pattern:
# - .env / .env.*        : Supabase, Sentry, Kakao, PortOne, GA secrets
# - credentials/         : GCP service account JSON lives here
# - *.pem / *.key        : TLS keys, JWT signing keys
# - **/secrets/          : conventional secret directories
# - .ssh/                : SSH private keys (local dev leak vector)
# - firebase*.json       : Firebase service accounts
# - service-account*.json: GCP service accounts
read -r -d '' FORBIDDEN_PATTERNS <<'PATTERNS' || true
(^|/)\.env($|\.)
(^|/)credentials/
\.pem$
\.key$
(^|/)secrets/
(^|/)\.ssh/
(^|/)firebase.*\.json$
(^|/)service-account.*\.json$
PATTERNS

while IFS= read -r pattern; do
  [ -z "$pattern" ] && continue
  if printf '%s' "$NORMALIZED" | grep -Eq "$pattern"; then
    cat >&2 <<EOF
❌ Security guard: write blocked.

Path:    $FILE_PATH
Matched: $pattern

This path holds or resembles a secret-bearing file. Writing secrets to the
repo is never legitimate — if you need to rotate or template these values,
do it outside the repo (Secret Manager, Vercel env, local .env not tracked
by git) or ask the user to perform the change manually.

If this is a false positive (e.g. a test fixture), rename the file so it
doesn't match the patterns in .claude/hooks/security-guard.sh.
EOF
    exit 2
  fi
done <<< "$FORBIDDEN_PATTERNS"

exit 0
