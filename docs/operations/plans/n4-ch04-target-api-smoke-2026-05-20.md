# N4 Target API Lesson Smoke

> Generated: 2026-05-20T08:00:17Z
> Status: PASS
> Boundary: authenticated read-only list/detail API smoke; no start, submit, or TTS generation calls

## Target

- API base: `https://harukoto-api-842843944454.asia-northeast3.run.app`
- Account: `t***@harukoto.co.kr`
- Chapters: `4`
- Lessons: `16`

## Target Lessons

| Lesson | Chapter | Chapter lesson | Title | Detail ID |
|---|---:|---:|---|---|
| `HN4-012` | 4 | 1 | 이유를 나란히 말해요 | `d4633ddc-7d4a-4c57-ab33-79dc472d9905` |
| `HN4-013` | 4 | 2 | 한번 확인해 봐요 | `254bf018-bbdc-41f7-9458-67cedba4a4c7` |
| `HN4-014` | 4 | 3 | 미리 준비해 둬요 | `a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc` |
| `HN4-015` | 4 | 4 | 깜빡 잊어버렸어요 | `e812f2e7-4e5e-4e02-b566-47893239c20c` |
| `HN4-016` | 4 | 5 | 연습을 계속해요 | `ca89a60e-8cbf-41f4-8345-87cc0ac763ef` |

## Detail Checks

| Lesson | Result | Script lines | Questions | Vocab items | Grammar items | Answer keys stripped |
|---|---|---:|---:|---:|---:|---|
| `HN4-012` | PASS | 4 | 5 | 6 | 1 | yes |
| `HN4-013` | PASS | 4 | 5 | 5 | 1 | yes |
| `HN4-014` | PASS | 4 | 5 | 6 | 1 | yes |
| `HN4-015` | PASS | 4 | 5 | 6 | 1 | yes |
| `HN4-016` | PASS | 4 | 5 | 6 | 1 | yes |

## Blockers

- None

## Assumptions

- This smoke is read-only after password sign-in; it only calls published chapters and lesson detail APIs.
- It does not call lesson start, submit, or TTS generation endpoints.
- The authenticated account label is masked so rollout evidence does not expose credentials or tokens.
