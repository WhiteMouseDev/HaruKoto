# N4 Pilot TTS Audio Quality Preflight

> Date: 2026-05-13
> Scope: published N4 controlled-pilot lesson TTS, HN4-001 through HN4-011
> Status: PASS for machine blockers; human audio-quality review still pending

## Boundary

This is an automated preflight for generated lesson TTS audio files. It checks
record/text consistency, HTTP download, MP3 probing, duration bounds, and
silence ratio heuristics.

It does not replace human listening review, native-speaker pronunciation
judgment, or broad/full N4 rollout approval.

ASSUMPTION: Machine preflight can reject obviously broken audio, but it cannot
approve pronunciation quality or learner acceptability.

## Command

```bash
cd apps/api
uv run python scripts/audit_n4_pilot_tts_audio_quality.py \
  --level N4 \
  --fail-on-blocker
```

## Summary

| Metric | Result |
|---|---:|
| Total targets checked | 99 |
| Passed machine blockers | 99 |
| Blocked targets | 0 |
| Warning count | 11 |
| Provider/model | `elevenlabs/eleven_multilingual_v2`: 99 |
| Duration min | 1.437s |
| Duration max | 8.673s |
| Duration average | 3.819s |
| Total audio duration | 378.044s |

## Warnings For Human Review

These are not machine blockers. They should be prioritized during human audio
QA because they may indicate long pauses in question-prompt playback.

- `HN4-001 question:3`: `HIGH_SILENCE_RATIO:0.3863`
- `HN4-002 question:4`: `HIGH_SILENCE_RATIO:0.3876`
- `HN4-003 question:3`: `HIGH_SILENCE_RATIO:0.3646`
- `HN4-003 question:4`: `HIGH_SILENCE_RATIO:0.4078`
- `HN4-004 question:4`: `HIGH_SILENCE_RATIO:0.3813`
- `HN4-005 question:4`: `HIGH_SILENCE_RATIO:0.3968`
- `HN4-006 question:4`: `HIGH_SILENCE_RATIO:0.3523`
- `HN4-008 question:3`: `HIGH_SILENCE_RATIO:0.4026`
- `HN4-009 question:4`: `HIGH_SILENCE_RATIO:0.4041`
- `HN4-010 question:4`: `HIGH_SILENCE_RATIO:0.3915`
- `HN4-011 question:3`: `HIGH_SILENCE_RATIO:0.359`

## Decision

The generated N4 pilot TTS set has no machine-detected blockers. This supports
moving to human listening QA instead of regenerating the batch immediately.

Broad/full N4 rollout remains on HOLD until the human audio QA packets are
reviewed and any `FLAG` or `FAIL` items are resolved or explicitly waived.

Follow-up human review packets are prepared for all 99 generated targets:
`docs/operations/plans/n4-pilot-human-audio-qa-packets-2026-05-13.md`.
