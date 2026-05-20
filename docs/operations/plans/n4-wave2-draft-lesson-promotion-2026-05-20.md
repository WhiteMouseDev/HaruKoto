# N4 Wave 2 Draft Lesson Promotion

> Date: 2026-05-20
> Scope: promote the next N4 foundation slice into official DRAFT lesson source
> Status: official DRAFT source promoted and TTS generated; learner-facing PILOT is on hold until human audio QA

## Decision

Promote five HaruKoto-authored N4 seed candidates into official lesson JSON as
`DRAFT` source:

| Lesson | Topic | Grammar anchor | Runtime status |
|---|---|---|---|
| `HN4-012` | `し` | `〜し` / order 24 | official source, not published |
| `HN4-013` | `てみる` | `Vて + みる` / order 4 | official source, not published |
| `HN4-014` | `ておく` | `Vて + おく` / order 3 | official source, not published |
| `HN4-015` | `てしまう` | `Vて + しまう` / order 1 | official source, not published |
| `HN4-016` | `つづける` | `Vます stem + 続ける` / order 35 | official source, not published |

ASSUMPTION: The user-authorized delegated AI review path is sufficient for
official DRAFT source promotion. This remains lower authority than
native-speaker curriculum review and does not approve learner-facing PILOT.

## Why DRAFT

The previous N4 audio QA gate is clean for existing pilot lessons, but these
five lessons introduce new script lines and question prompts. They therefore
must not become learner-facing until the TTS generation and audio QA loop runs
for `HN4-012` through `HN4-016`.

Keeping chapter `N4-CH04` as `meta.status=DRAFT` means the package source can
be reviewed and tracked without entering the configured API seed registry. The
registry continues to carry only pilot/publishable N4 sources until audio QA is
complete.

## Changed Source Files

- `packages/database/data/lessons/n4/ch04-everyday-action-extensions.json`
  - official DRAFT lesson source for `HN4-012` through `HN4-016`.
- `packages/database/data/curriculum/lesson-seed-candidates.json`
  - source candidates and promotion targets for the new DRAFT lessons.
- `packages/database/data/curriculum/example-bank.json`
  - HaruKoto-authored example sentences for the new N4 topics.
- `packages/database/scripts/derive-curriculum-topics.mjs`
  - coverage overrides map the new official DRAFT lesson IDs to their topics.
- `packages/database/data/curriculum/lesson-seed-candidate-review/n4-candidate-review.json`
  - candidate review packet records delegated AI approval for the new slice.
- `packages/database/data/curriculum/lesson-human-review/n4-pilot-review.json`
  - official lesson review packet includes `HN4-012` through `HN4-016`.
- `packages/database/data/curriculum/tts-target-manifest.json`
  and `apps/api/app/data/curriculum/tts-target-manifest.json`
  - regenerated TTS target manifests include new official lesson targets.
- `apps/api/app/seeds/lessons.py`
  - adds an explicit `--extra-content-file` path for DRAFT ops without adding
    `N4-CH04` to the default seed registry.
- `apps/api/scripts/generate_n4_pilot_tts_batch.py`,
  `apps/api/scripts/audit_n4_pilot_tts_audio_quality.py`, and
  `apps/api/scripts/build_n4_audio_qa_packet.py`
  - add explicit `--include-unpublished` support so draft lessons can enter
    TTS generation and audio QA only when the operator opts in. The audio
    audit path can also narrow scope with repeatable `--lesson-no` filters.
- `apps/api/app/services/lesson_script_tts.py`
  - keeps the normal lesson TTS service on published lessons by default, with
    an explicit ops-only unpublished override for DRAFT TTS generation.

## Seed Registry Boundary

`apps/api/app/seeds/lessons.py` is intentionally unchanged. The configured API
seed registry only carries pilot/publishable N4 sources, so `N4-CH04` enters
that registry after TTS generation and audio QA.

## Validation Evidence

| Gate | Result |
|---|---|
| Lesson validation | PASS with expected DRAFT warning for `N4-CH04` |
| Candidate review validation | PASS |
| Lesson human review validation | PASS |
| Candidate review gate | PASS for `N4` |
| Official review gate | PASS for `N4` |
| Curriculum validation | PASS |
| Database package typecheck | PASS |
| API seed policy tests | PASS |
| Draft seed/TTS ops unit tests | PASS |
| Draft seed/TTS ops CLI syntax | PASS |
| Draft TTS machine audio probe | PASS for 45/45 targets; one non-blocking silence-ratio warning remains for human review |
| Draft TTS STT assist | REVIEW for 45/45 targets; 29 STT mismatches require human listening before rollout |
| Draft human audio QA packet | REVIEW PACKET generated for 45 targets; all audio URLs passed URL checks |
| Draft audio QA review queue | REVIEW QUEUE generated with P0/P1/P2 ordering and an HTML listening sheet |
| Configured N4 DB seed check | PASS for existing 11 publishable N4 lessons; `N4-CH04` intentionally excluded while DRAFT |

## Boundary

This promotion increases official N4 lesson source coverage from 11 to 16
lessons. It does not make the new lessons learner-facing and does not claim
native-speaker or audio QA approval.

Next gates:

1. Complete human/listener verdicts for the 45 `HN4-012` through `HN4-016`
   targets in the Chapter 4 packet/review sheet.
2. Regenerate or explicitly waive any `FLAG` / `FAIL` items.
3. Move `N4-CH04` from `DRAFT` to `PILOT` only after the human audio gate is
   clean.
