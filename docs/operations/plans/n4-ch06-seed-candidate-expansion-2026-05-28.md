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

## Controlled Pilot Update - 2026-05-29

The five CH06 candidates were promoted into the official N4 seed registry as
`N4-CH06` / HN4-022 through HN4-026 with `meta.status: "PILOT"`. The promoted
lesson file keeps the same copyright boundary: paid PDFs were coverage anchors
only, while examples, dialogues, prompts, and explanations are HaruKoto-authored
content.

The promotion is cleared for controlled pilot exposure by AI-only review,
seed-sync checks, full TTS generation, machine audio QA, STT-assisted triage,
and local lesson-flow smoke tests. It is still not native-speaker or formal
human approval. See
`docs/operations/plans/n4-ch06-pilot-rollout-decision-2026-05-29.md` for the
current rollout decision and evidence.

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

All checks above passed for the candidate-stage packet. This historical result
has been superseded by the 2026-05-29 controlled pilot promotion: refs 048, 049,
050, 078, and 080 now report `official_seed`, and the official N4 DB seed is 6
chapters / 26 lessons with 234/234 generated pilot TTS records.

## Next Gate

1. DONE on 2026-06-01 for deploy, configured DB seed sync, read-only
   service-path list/detail smoke, and authenticated remote HTTP list/detail
   smoke.
2. DONE on 2026-06-01 for representative HN4-022 mobile target-runtime UAT:
   lesson detail, start, vocab TTS, dialogue TTS, quiz completion, SRS
   registration, retry, and return-to-learning.
3. DONE on 2026-06-01 for the first CH06 pilot-feedback baseline: no automatic
   rollback trigger, HN4-022 same-day runtime completion observed, HN4-023
   through HN4-026 waiting for learner traffic, and TTS records complete.
4. Continue pilot-feedback refreshes over time.
5. Keep native-speaker/human approval as a separate post-pilot quality gate.
