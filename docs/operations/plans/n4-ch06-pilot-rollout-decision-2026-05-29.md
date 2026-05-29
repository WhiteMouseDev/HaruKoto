# N4 CH06 Pilot Rollout Decision - 2026-05-29

## Decision

Status: LIMITED GO for controlled pilot exposure of N4 CH06.

Scope: `N4-CH06` / HN4-022 through HN4-026:

- HN4-022: `〜てあげる`
- HN4-023: `〜てくれる`
- HN4-024: `〜てもらう`
- HN4-025: `〜のに`
- HN4-026: passive form `〜(ら)れる`

ASSUMPTION: The user-approved AI-only review path is acceptable for early,
free-app pilot exposure, but this is not native-speaker or formal human
approval.

## Evidence

| Gate | Result | Evidence |
|---|---:|---|
| Official seed source | PASS | Added `ch06-benefactive-contrast-and-passive.json` with 5 PILOT lessons, 20 script lines, and 25 questions. |
| Candidate review | PASS | `candidates:review:gate -- --level N4`: APPROVED 5, PENDING 0, blockers 0. |
| Official lesson review | PASS | `lessons:review:gate -- --level N4`: N4 rows 26, APPROVED 26, PENDING 0, blockers 0. |
| Lesson content quality | PASS | `lessons:quality -- --level N4 --strict-warnings`: 7 PASS / 0 WARN / 0 FAIL. |
| Curriculum contracts | PASS | `curriculum:validate`: warnings 0, failures 0. |
| Lesson contracts | PASS | `lessons:validate`: chapters 15, lessons 76, questions 380, vocabulary links 434, grammar links 76. |
| Local DB seed sync | PASS | `app.seeds.lessons --check --level N4`: chapters 6, lessons 26, missing 0, content mismatches 0, item link mismatches 0. |
| TTS generation | PASS | Generated 45/45 missing CH06 script/question records with 0 failures. |
| N4 TTS coverage | PASS | `report_n4_pilot_tts_coverage.py --fail-on-missing`: 234/234 records generated, 234/234 audio URLs OK. |
| Machine audio QA | PASS with review notes | 45/45 pass, blockers 0, warnings 2 high-silence-ratio rows: HN4-022 question:3 and HN4-024 question:3. |
| STT-assisted triage | REVIEW, not blocker | 45 transcribed, 8 exact matches, 37 mismatches, 0 STT errors, strict blocker mode `no`. Mixed Korean/Japanese prompts produce known STT false positives, so this remains a review signal. |
| Local lesson-flow smoke | PASS | HN4-022 through HN4-026: correct flow 5/5, wrong flow 0/5, status COMPLETED, residue 0. |

## Audio Boundary

The machine audio probe found no broken URLs, empty files, invalid formats, or
blocking audio defects. STT mismatches are preserved in
`n4-ch06-pilot-tts-stt-assist-run-2026-05-29.md` and should be treated as
review-priority rows, not as native audio approval.

Because no human Japanese expert is available for this pilot, the exposure
decision relies on AI curriculum review, structural validation, local API smoke,
machine audio QA, and user feedback after release.

## Rollback

If pilot feedback shows a content or audio blocker:

1. Remove `ch06-benefactive-contrast-and-passive.json` from
   `CONTENT_FILES_BY_LEVEL["N4"]`, or change the source status and seed policy
   to keep CH06 unpublished.
2. Rerun `curriculum:derive`, `lessons:review:prepare -- --level N4`,
   `curriculum:validate`, `lessons:validate`, and `lessons:quality`.
3. Rerun `uv run python -m app.seeds.lessons --level N4` in the target DB.
4. Confirm `uv run python -m app.seeds.lessons --check --level N4` returns no
   mismatches and that the target API no longer exposes HN4-022 through HN4-026.

## Remaining Gates

- Remote target environment seed/deploy and API smoke are not proven in this
  packet.
- Mobile target-runtime UAT is not proven in this packet.
- Native-speaker or formal human approval remains a later quality gate.
- Pilot feedback should be monitored for confusing Korean prompts, unnatural
  Japanese, and TTS playback complaints before broad release positioning.
