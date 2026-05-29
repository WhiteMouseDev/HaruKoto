# N4 CH06 Seed Candidate Expansion - 2026-05-28

## Scope

This packet expands the N4 lesson pipeline with five new HaruKoto-authored
seed candidates. The paid PDF files under `~/Downloads/japanese` were used only
as coverage anchors; dialogue, examples, prompts, and explanations were newly
authored.

ASSUMPTION: These rows are candidate-stage learning data, not learner-facing
official DB seed lessons.

ASSUMPTION: Delegated AI review can reduce launch risk, but it is not native
speaker or formal human approval.

## Candidate Slice

| Candidate | Topic | Target slot | PDF ref | Status |
|---|---|---:|---:|---|
| `lsc-n4-te-ageru-001` | `〜てあげる` | HN4-022 | 048 | candidate only |
| `lsc-n4-te-kureru-001` | `〜てくれる` | HN4-023 | 049 | candidate only |
| `lsc-n4-te-morau-001` | `〜てもらう` | HN4-024 | 050 | candidate only |
| `lsc-n4-noni-001` | `〜のに` | HN4-025 | 078 | candidate only |
| `lsc-n4-passive-form-001` | passive form | HN4-026 | 080 | candidate only |

The slice moves the five PDF refs from backlog/blueprint-only reporting into
`seed_candidate_only` coverage. The configured N4 DB seed remains CH01-CH05
with 21 official lessons until review, TTS generation, audio QA, and promotion
are completed.

## Review Notes

Two delegated AI reviews were run on the initial candidate content. They flagged
three issues before promotion:

| Candidate | Finding | Resolution |
|---|---|---|
| `lsc-n4-te-ageru-001` | `受付も紹介してあげましたか` and `相談を聞いてあげます` sounded unnatural. | Rewrote to `受付の場所も教えてあげましたか` and `話を聞いてあげます`; updated Q4. |
| `lsc-n4-te-morau-001` | Korean glosses such as "써 받았습니다" were too literal. | Rewrote the example and lesson script around `受付の人に住所を確認してもらいました`; updated Korean prompts/glosses. |
| `lsc-n4-passive-form-001` | Q4 produced the wrong passive form and the theft report dialogue used awkward wording. | Rewrote Q4 to `声をかけられて`; replaced `事故`/camera phrasing with theft-safe passive examples. |

These fixes were regenerated into the candidate review packet and TTS target
manifest before validation.

## AI Approval Update - 2026-05-29

The five N4 CH06 candidate review rows were moved from `PENDING` to
`APPROVED` after delegated AI review, targeted rewrites, and a final self-review
against candidate-stage N4 fit, Korean learner clarity, prompt compatibility,
and TTS target coverage.

This clears the candidate curriculum review gate only. It does not promote the
rows into the official N4 DB seed, does not make the generated TTS targets
audio-ready, and must not be represented as native-speaker or formal human
approval.

Approval validation after this update:

```bash
pnpm --filter @harukoto/database candidates:review:validate
pnpm --filter @harukoto/database candidates:review:gate -- --level N4
pnpm --filter @harukoto/database curriculum:validate
pnpm --filter @harukoto/database typecheck
pnpm --filter @harukoto/database curriculum:lesson-expansion:report -- \
  --pdf-dir ~/Downloads/japanese \
  --json-output /tmp/harukoto-expansion-report-after-ai-approval.json
cd apps/api && uv run python -m app.seeds.lessons --check --level N4
git diff --check
```

All checks above passed. The candidate review gate now reports
`APPROVED: 5`, `PENDING: 0`, and `blockers: 0`. The official N4 DB seed remains
5 chapters and 21 lessons; PDF refs 048, 049, 050, 078, and 080 remain
`seed_candidate_only`.

## TTS Impact

The candidate review packet now has full target coverage:

| Target kind | Coverage |
|---|---:|
| example sentence | 5/5 |
| script line | 20/20 |
| question prompt | 25/25 |

The generated TTS targets are still `generationStatus: "missing"`. They should
not be treated as audio-ready until the normal generation and audio QA loop is
run.

## Validation

```bash
pnpm --filter @harukoto/database curriculum:derive
pnpm --filter @harukoto/database candidates:review:prepare -- --level N4
pnpm --filter @harukoto/database curriculum:validate
pnpm --filter @harukoto/database typecheck
pnpm --filter @harukoto/database lessons:validate
pnpm --filter @harukoto/database lessons:quality -- --level N4 --strict-warnings
pnpm --filter @harukoto/database curriculum:lesson-expansion:report -- \
  --pdf-dir ~/Downloads/japanese \
  --json-output /tmp/harukoto-expansion-report-after.json
cd apps/api && uv run python -m app.seeds.lessons --check --level N4
cd apps/api && uv run python scripts/report_n4_pilot_tts_coverage.py \
  --level N4 --check-audio-urls --fail-on-missing --json
git diff --check
```

All checks above passed. The expansion report shows the new refs as
`seed_candidate_only`; the official N4 DB seed and pilot TTS coverage remain
unchanged at 21 lessons and 189/189 generated TTS records.

## Next Gate

1. Generate candidate TTS and run AI/STT-assisted audio QA before adding CH06 to
   the official N4 seed registry.
2. Promote the five candidates into the official N4 seed registry only after the
   candidate audio QA packet is clean and the promotion diff is validated.
3. Keep native-speaker/human approval as a separate launch-readiness gate.
