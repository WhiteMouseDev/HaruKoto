# N5 TTS Audio QA Machine Report — 2026-10-26

> **10월 26일 기계 검사 증거:** 아래 수치·파일 지문은 당시 결과이며 현재 전체 음원이나 발음의 승인이 아니다. HN5-004 네 파일 교체와 이후 적용 상태는 [현재 상태](n5-audio-qa-current-state-2026-10-28.md)를 따른다. 이번 갱신에서 아래 파일 판정을 재작성하지 않는다.

> Status: REVIEW
> Scope: generated lesson script-line and question-prompt TTS targets
> Boundary: machine/STT evidence only; human audio verdicts remain required

## Inspection method

Used a private snapshot-only bounded HTTPS GET runner with local ffprobe/ffmpeg. The runner read the reviewed public-content export without connecting to a DB, invoking STT/TTS generation, or applying verdicts. This describes the inspection method; it is not a shell command.

## Summary

| Metric               |    Result |
| -------------------- | --------: |
| Total targets        |       448 |
| Machine pass         |       448 |
| Blocked targets      |         0 |
| Warning count        |        36 |
| Transcribed targets  |         0 |
| STT exact matches    |         0 |
| STT mismatches       |         0 |
| STT errors           |         0 |
| Duration min         |    1.115s |
| Duration max         |   11.378s |
| Duration average     |     4.09s |
| Total audio duration | 1832.387s |

## Provider Models

- `elevenlabs/eleven_multilingual_v2`: 448

## Blockers

- None

## Review-Priority Warnings

- HN5-001 question:4: HIGH_SILENCE_RATIO:0.4449
- HN5-003 question:3: HIGH_SILENCE_RATIO:0.3751
- HN5-005 question:3: HIGH_SILENCE_RATIO:0.4514
- HN5-005 question:4: HIGH_SILENCE_RATIO:0.443
- HN5-008 question:3: HIGH_SILENCE_RATIO:0.4416
- HN5-011 question:4: HIGH_SILENCE_RATIO:0.3881
- HN5-014 question:4: HIGH_SILENCE_RATIO:0.403
- HN5-015 question:3: HIGH_SILENCE_RATIO:0.5246
- HN5-015 question:4: HIGH_SILENCE_RATIO:0.375
- HN5-016 question:4: HIGH_SILENCE_RATIO:0.4449
- HN5-017 question:4: HIGH_SILENCE_RATIO:0.4692
- HN5-018 question:3: HIGH_SILENCE_RATIO:0.5172
- HN5-018 question:4: HIGH_SILENCE_RATIO:0.5177
- HN5-019 question:3: HIGH_SILENCE_RATIO:0.5317
- HN5-020 question:3: HIGH_SILENCE_RATIO:0.409
- HN5-020 question:4: HIGH_SILENCE_RATIO:0.4471
- HN5-021 question:4: HIGH_SILENCE_RATIO:0.4219
- HN5-022 question:3: HIGH_SILENCE_RATIO:0.5132
- HN5-022 question:4: HIGH_SILENCE_RATIO:0.408
- HN5-024 question:3: HIGH_SILENCE_RATIO:0.4418
- HN5-024 question:4: HIGH_SILENCE_RATIO:0.3941
- HN5-028 question:4: HIGH_SILENCE_RATIO:0.3857
- HN5-030 question:3: HIGH_SILENCE_RATIO:0.4488
- HN5-030 question:4: HIGH_SILENCE_RATIO:0.5149
- HN5-031 question:4: HIGH_SILENCE_RATIO:0.5423
- HN5-032 question:3: HIGH_SILENCE_RATIO:0.3759
- HN5-034 question:3: HIGH_SILENCE_RATIO:0.3734
- HN5-034 question:4: HIGH_SILENCE_RATIO:0.4714
- HN5-035 question:3: HIGH_SILENCE_RATIO:0.3835
- HN5-036 question:3: HIGH_SILENCE_RATIO:0.3693
- HN5-038 script:1: HIGH_SILENCE_RATIO:0.3642
- HN5-040 question:3: HIGH_SILENCE_RATIO:0.4997
- HN5-041 script:3: HIGH_SILENCE_RATIO:0.4276
- HN5-041 question:3: HIGH_SILENCE_RATIO:0.4443
- HN5-043 question:4: HIGH_SILENCE_RATIO:0.4329
- HN5-048 question:4: HIGH_SILENCE_RATIO:0.4009

## STT Mismatches

- None

## Decision

REVIEW: inspect non-blocking warnings before recording final audio verdicts.

## Evidence boundary

Current snapshot / public file metadata only. Human listening and native-speaker approval were not performed; all reviewer verdicts remain PENDING. Transport, TLS and probe runtime failures are verification limitations, not confirmed pronunciation defects. Exact/strip/SHA alignment is reported separately from existing punctuation-normalized machine checks.

## Currentness and input checks

Snapshot: `2026-10-26 06:59:53.922749+00:00`. Raw text, runtime strip and existing punctuation-normalized checks each match 448/448. Full audio SHA recheck: 448/448. Total unique file bytes: 29,791,585.

Combined target/source/stored/audio hash fingerprint: `a1877c6910db6ae72b3dfa534528dae9ade5045317198c26b6ad9896e004c65b`.

The first default-sandbox attempt had 0 HTTP responses and was retained as an environment-limited attempt. The successful allowed-network run fetched each public URL once with TLS verification, no redirects, 2 MiB/file, 15-second whole-request and 20-second local probe budgets. No DB, TTS generation, STT, listening or verdict application was performed.

[Current packet index](n5-human-audio-qa-packets-2026-10-26.md).
