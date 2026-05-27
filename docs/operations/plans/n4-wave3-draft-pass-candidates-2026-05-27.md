# N4 Audio QA AI-Assisted PASS Candidates

> Status: PASS CANDIDATES - no verdicts applied
> Boundary: machine/STT-assisted triage only; does not approve rollout

ASSUMPTION: A candidate means the target is still `PENDING`, has machine
audio pass evidence, and has no parsed machine/STT review signal. It is
not a final human audio-quality verdict.

## Sources

- Packet: `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-tts-machine-report-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-tts-stt-assist-run-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-tts-stt-timeout-retry-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-lexical-risk-stt-retry-2026-05-27.md`

## Summary

| Metric | Count |
|---|---:|
| Total review items | 45 |
| Pending verdicts | 41 |
| AI-assisted PASS candidates | 6 |
| Held for listening/regeneration review | 35 |
| Machine-warning items | 0 |
| STT-mismatch signal items | 34 |

## Candidate Criteria

- Current verdict is `PENDING`.
- Priority is `P2 pending` in the review queue.
- No parsed `HIGH_SILENCE_RATIO`, `TRANSCRIPTION_TEXT_MISMATCH`, or other machine/STT review signal is attached.
- Candidate status only reduces review order; it does not replace listening.

## Candidate CSV Contract

The companion CSV leaves `new_verdict` and `new_notes` blank on purpose.
After listening, set `new_verdict=PASS` only for rows that are complete,
intelligible, and acceptable for learner playback. Keep uncertain rows
`PENDING`, or mark `FLAG` / `FAIL` in the source verdict workflow.

## Candidates

| Target | Japanese text | Korean/context | Audio | Candidate reason | Recommended action | Packet |
|---|---|---|---|---|---|---|
| HN4-017 script:0 | 週末は掃除をしたり、洗濯をしたりします。 | 주말에는 청소를 하거나 빨래를 하거나 합니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/script-line-0.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-017 script:2 | はい。来週の準備をしたり、部屋を片付けたりします。 | 네. 다음 주 준비를 하거나 방을 정리하거나 합니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/script-line-2.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-017 script:3 | 生活の習慣を話す時に便利ですね。 | 생활 습관을 말할 때 편리하네요. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/script-line-3.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-018 script:1 | 会議で使うのは無理そうですね。 | 회의에서 쓰기는 무리일 것 같네요. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-1.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-019 script:1 | 予定が変わるそうですね。 | 예정이 바뀐다고 하네요. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-1.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-019 script:2 | 試験は思ったより簡単だそうです。 | 시험은 생각보다 쉽다고 합니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-2.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |

## Held Items

P0 machine-warning and P1 STT-mismatch rows stay out of the candidate CSV.
They should be listened to before waiver or regenerated if the signal is
confirmed as a content, clipping, pacing, pronunciation, or prompt-shape issue.

## Decision

Use this file to batch the safest listen-once checks first. Broad/full N4
rollout remains blocked until packet verdicts contain no `PENDING`,
`FLAG`, `FAIL`, or invalid values.
