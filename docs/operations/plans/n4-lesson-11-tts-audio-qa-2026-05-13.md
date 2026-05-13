# N4 Lesson 11 TTS Audio QA

> Date: 2026-05-13
> Scope: HN4-011 learner-facing dialogue script-line TTS
> Status: PASS for generated script-line audio and machine playback readiness

## Boundary

This run verifies the TTS surface that the current mobile lesson UI can play:
dialogue script lines through
`POST /api/v1/lessons/{lesson_id}/script-lines/{line_index}/tts`.

It does not claim native-speaker audio quality approval, nor does it generate
question-prompt TTS. Question prompts remain part of the broader lesson-seed
TTS backlog because the current mobile learner flow does not expose a prompt
playback surface.

ASSUMPTION: For HN4-011 limited pilot exposure, learner-facing dialogue
script-line TTS generation plus URL/codec verification is sufficient to close
the immediate mobile playback-readiness gate. Human audio-quality review remains
required before broad/full N4 rollout.

## Target

| Field | Value |
|---|---|
| Lesson | `HN4-011` |
| Lesson ID | `03cfdb15-c916-450c-8168-9052f3e754aa` |
| Title | `종이의 두께를 비교해요` |
| TTS target type | `lesson_script_line` |
| Field | `script_line` |
| Provider | `elevenlabs` |
| Model | `eleven_multilingual_v2` |

## Evidence

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

Mobile runtime probe:

- The iPhone 17 Pro Simulator opened HN4-011 and reached the dialogue reading
  screen.
- Tapping the first dialogue-line speaker control triggered
  `POST /api/v1/lessons/03cfdb15-c916-450c-8168-9052f3e754aa/script-lines/0/tts`
  and returned `200`.
- During the probe, debug DIO logging was found to print raw `Authorization`
  headers. Mobile debug logging now redacts sensitive header and token
  parameters before full target mobile UAT continues.

## Result

HN4-011 learner-facing dialogue TTS is generated, reachable, and decodable.
The remaining HN4-011 learner-readiness gate is target mobile UAT for one
correct path and one wrong-answer retry path.
