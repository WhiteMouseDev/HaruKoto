# N4 Lesson 11 TTS Audio QA

> Date: 2026-05-13
> Scope: HN4-011 lesson TTS audio generation and machine playback readiness
> Status: PASS for generated script-line and question-prompt audio

## Boundary

This run verifies the HN4-011 lesson TTS surfaces now supported by the API:

- dialogue script lines through
  `POST /api/v1/lessons/{lesson_id}/script-lines/{line_index}/tts`
- question prompts through
  `POST /api/v1/lessons/{lesson_id}/questions/{question_order}/tts`

It does not claim native-speaker audio quality approval. The mobile learner
flow currently exercises script-line playback; question-prompt audio is
generated for lesson-seed completeness and broad-rollout readiness.

ASSUMPTION: For HN4-011 limited pilot exposure, generated lesson TTS plus
URL/codec verification is sufficient to close the automated playback-readiness
gate. Human audio-quality review remains required before broad/full N4 rollout.

## Target

| Field | Value |
|---|---|
| Lesson | `HN4-011` |
| Lesson ID | `03cfdb15-c916-450c-8168-9052f3e754aa` |
| Title | `종이의 두께를 비교해요` |
| Script-line target type | `lesson_script_line` |
| Script-line field | `script_line` |
| Question target type | `lesson_question_prompt` |
| Question field | `question_prompt` |
| Provider | `elevenlabs` |
| Model | `eleven_multilingual_v2` |

## Script-Line Evidence

The configured API route was called once per script line with a smoke user
dependency override. Each call returned `200` and persisted one
`tts_audio` row.

| Line | Endpoint | HTTP audio check | Decode check |
|---|---:|---|---|
| 0 | 200 | `200 audio/mpeg`, 85725 bytes | mp3, 5.328980s |
| 1 | 200 | `200 audio/mpeg`, 53124 bytes | mp3, 3.291429s |
| 2 | 200 | `200 audio/mpeg`, 67335 bytes | mp3, 4.179592s |
| 3 | 200 | `200 audio/mpeg`, 66499 bytes | mp3, 4.127347s |

Post-run DB check:

- `script_tts_records`: 4 / 4
- Stored provider/model: `elevenlabs` / `eleven_multilingual_v2`
- Generated paths: `tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-{0..3}.mp3`

## Question-Prompt Evidence

The configured generation path was called once per HN4-011 question order. Each
call persisted one `tts_audio` row with target IDs shaped as
`03cfdb15-c916-450c-8168-9052f3e754aa:question:{1..5}`.

| Question order | HTTP audio check | Decode check |
|---:|---|---|
| 1 | `200 audio/mpeg`, 25539 bytes | mp3, 1.567347s |
| 2 | `200 audio/mpeg`, 27211 bytes | mp3, 1.671837s |
| 3 | `200 audio/mpeg`, 99100 bytes | mp3, 6.164898s |
| 4 | `200 audio/mpeg`, 139224 bytes | mp3, 8.672653s |
| 5 | `200 audio/mpeg`, 75276 bytes | mp3, 4.675918s |

Post-run DB check:

- `question_prompt_tts_records`: 5 / 5
- Stored provider/model: `elevenlabs` / `eleven_multilingual_v2`
- Generated paths: `tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-{1..5}.mp3`

## Mobile Runtime Probe

- The iPhone 17 Pro Simulator opened HN4-011 and reached the dialogue reading
  screen.
- Tapping the first dialogue-line speaker control triggered
  `POST /api/v1/lessons/03cfdb15-c916-450c-8168-9052f3e754aa/script-lines/0/tts`
  and returned `200`.
- During the probe, debug DIO logging was found to print raw `Authorization`
  headers. Mobile debug logging now redacts sensitive header and token
  parameters before full target mobile UAT continues.

## Result

HN4-011 script-line and question-prompt TTS are generated, reachable, and
decodable. This closes the automated HN4-011 lesson TTS generation/codec gate.
Broad/full N4 rollout still requires human audio-quality review and the wider
pilot/batch TTS decision.
