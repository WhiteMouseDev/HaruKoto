---
status: ready
scope: vercel-monorepo-ignore
created: 2026-05-13T16:36:00+09:00
source:
  - scripts/vercel-ignore.sh
  - apps/admin/vercel.json
  - apps/web/vercel.json
  - apps/landing/vercel.json
---

# Vercel Monorepo Ignore Runbook

This runbook records the Vercel ignored-build setup for the HaruKoto
monorepo. It exists because Vercel project settings are external state: the
repo contains `vercel.json`, but the Dashboard/API value can drift.

## Current Projects

| Vercel project | Root directory | Ignore command |
| --- | --- | --- |
| `harukoto-admin` | `apps/admin` | `bash "$(git rev-parse --show-toplevel)/scripts/vercel-ignore.sh" apps/admin packages/config packages/database packages/types` |
| `haru_koto` | `apps/web` | `bash "$(git rev-parse --show-toplevel)/scripts/vercel-ignore.sh" apps/web packages/ai packages/database` |
| `haru_koto_landing` | `apps/landing` | `bash "$(git rev-parse --show-toplevel)/scripts/vercel-ignore.sh" apps/landing` |

These values were verified through the Vercel Project API on 2026-05-13.

## Repo Contract

The shared ignore script is `scripts/vercel-ignore.sh`.

Expected exit behavior:

| Exit code | Meaning |
| --- | --- |
| `0` | Ignore the Vercel build because no relevant path changed. |
| `1` | Continue the Vercel build because a relevant path changed or the diff cannot be safely computed. |

Common paths always trigger a build:

- `package.json`
- `pnpm-lock.yaml`
- `pnpm-workspace.yaml`
- `turbo.json`
- `scripts/vercel-ignore.sh`

## Local Verification

Use the previous and current commit SHAs that Vercel would compare:

```bash
export PREVIOUS_SHA=<previous-main-or-pr-base-sha>
export HEAD_SHA=<head-sha>

env VERCEL_GIT_PREVIOUS_SHA="$PREVIOUS_SHA" \
  VERCEL_GIT_COMMIT_SHA="$HEAD_SHA" \
  bash scripts/vercel-ignore.sh apps/landing

env VERCEL_GIT_PREVIOUS_SHA="$PREVIOUS_SHA" \
  VERCEL_GIT_COMMIT_SHA="$HEAD_SHA" \
  bash scripts/vercel-ignore.sh apps/web packages/ai packages/database

env VERCEL_GIT_PREVIOUS_SHA="$PREVIOUS_SHA" \
  VERCEL_GIT_COMMIT_SHA="$HEAD_SHA" \
  bash scripts/vercel-ignore.sh apps/admin packages/config packages/database packages/types
```

For an API-only or docs-only PR, all three commands should print
`No Vercel-relevant changes...` and exit `0`.

## Dashboard/API Drift Check

Use Vercel CLI auth without printing tokens:

```bash
node <<'NODE'
const fs = require('fs');
const path = require('path');
const authPath = path.join(
  process.env.HOME,
  'Library',
  'Application Support',
  'com.vercel.cli',
  'auth.json',
);
const auth = JSON.parse(fs.readFileSync(authPath, 'utf8'));
const token = auth.token;
const names = ['harukoto-admin', 'haru_koto', 'haru_koto_landing'];

(async () => {
  const res = await fetch('https://api.vercel.com/v9/projects?teamId=team_mCL76nQd0dwiJhHyTEvITBIR', {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) throw new Error(`GET projects failed ${res.status}: ${await res.text()}`);
  const data = await res.json();
  for (const name of names) {
    const project = data.projects?.find((item) => item.name === name);
    console.log(`${name}\t${project?.rootDirectory ?? ''}\t${project?.commandForIgnoringBuildStep ?? ''}`);
  }
})();
NODE
```

The output should match the `Current Projects` table.

## Reapply Settings

Use the Vercel Project API field `commandForIgnoringBuildStep`.

Do not commit Vercel auth tokens. Do not paste the token into docs or chat.

```bash
node <<'NODE'
const fs = require('fs');
const path = require('path');
const authPath = path.join(
  process.env.HOME,
  'Library',
  'Application Support',
  'com.vercel.cli',
  'auth.json',
);
const auth = JSON.parse(fs.readFileSync(authPath, 'utf8'));
const token = auth.token;
const teamId = 'team_mCL76nQd0dwiJhHyTEvITBIR';
const updates = [
  {
    name: 'harukoto-admin',
    id: 'prj_Rd3AQRXhJ40ZrTYhngQWuuPmysmV',
    ignore: 'bash "$(git rev-parse --show-toplevel)/scripts/vercel-ignore.sh" apps/admin packages/config packages/database packages/types',
  },
  {
    name: 'haru_koto',
    id: 'prj_9fCdW6sCJXQjsYD04S9c2lTUm5gW',
    ignore: 'bash "$(git rev-parse --show-toplevel)/scripts/vercel-ignore.sh" apps/web packages/ai packages/database',
  },
  {
    name: 'haru_koto_landing',
    id: 'prj_I38i6MH9AOMR7Wc30mCgrI5z4Uxa',
    ignore: 'bash "$(git rev-parse --show-toplevel)/scripts/vercel-ignore.sh" apps/landing',
  },
];

(async () => {
  for (const update of updates) {
    const res = await fetch(`https://api.vercel.com/v9/projects/${update.id}?teamId=${teamId}`, {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ commandForIgnoringBuildStep: update.ignore }),
    });
    if (!res.ok) throw new Error(`${update.name} PATCH failed ${res.status}: ${await res.text()}`);
    const data = await res.json();
    console.log(`${update.name}: ${data.commandForIgnoringBuildStep ?? ''}`);
  }
})();
NODE
```

## Build-Rate-Limit Status Handling

If a PR or main commit shows a Vercel status URL like:

```text
https://vercel.com/kunwookims-projects?upgradeToPro=build-rate-limit
```

then the check failed before useful build evidence was produced. Treat it as an
external quota blocker, not as a code build failure.

Decision rule:

- If GitHub Actions `changes`, affected app/backend jobs, contract checks, and
  deploy workflows pass, the code gate is green.
- Keep release notes explicit that Vercel status remains externally blocked.
- Rerun or redeploy the affected Vercel contexts after quota resets.

## References

- Vercel Project API: `commandForIgnoringBuildStep` is the project setting used
  by the Dashboard's ignored build step.
- Repo source of truth for path filters remains `scripts/vercel-ignore.sh`.
