# Phase 4: TTS Audio - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-27
**Phase:** 04-tts-audio
**Areas discussed:** 오디오 플레이어 UI, 재생성 플로우, 쿨다운 정책, 콘텐츠 타입별 TTS 텍스트

---

## 오디오 플레이어 UI

| Option | Description | Selected |
|--------|-------------|----------|
| 미니 플레이어 | 재생 버튼 + 파형 애니메이션 + 재생성 버튼을 한 줄로 컴팩트하게 | ✓ |
| 풀 컨트롤 | 재생/일시정지 + 시간 표시 + 시크바 + 재생성 버튼 | |
| 콘텐츠 타입별 다르게 | 단어/문법은 미니, 회화는 풀 컨트롤 | |

**User's choice:** 미니 플레이어
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| 재생성 유도 | 「오디오 없음 — 생성」 버튼 표시, 플레이어 영역 회색 비활성 | ✓ |
| 숨김 | 오디오 없으면 플레이어 영역 자체를 숨김 | |

**User's choice:** 재생성 유도
**Notes:** None

---

## 재생성 플로우

| Option | Description | Selected |
|--------|-------------|----------|
| 간단 확인 | 「{word}의 TTS를 재생성하시겠습니까?」 + 확인/취소 | ✓ |
| 상세 확인 | 현재 TTS 정보(provider, 생성일) + 대체 안내 포함 | |

**User's choice:** 간단 확인
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| 스피너 + 텍스트 | 버튼이 로딩 스피너로 변하고 「생성 중...」 표시 | ✓ |
| 프로그레스 바 | TTS 생성 진행률을 프로그레스 바로 표시 | |

**User's choice:** 스피너 + 텍스트
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| 자동 재생 | 생성 완료 시 자동으로 새 오디오 재생 | ✓ |
| 수동 재생 | 생성 완료 토스트만 표시 | |

**User's choice:** 자동 재생
**Notes:** None

---

## 쿨다운 정책

| Option | Description | Selected |
|--------|-------------|----------|
| 항목별 | A 단어 재생성 후 10분간 A만 제한, B는 바로 가능 | ✓ |
| 전체 제한 | TTS 재생성 1회 후 10분간 모든 항목 제한 | |

**User's choice:** 항목별
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| 남은 시간 표시 | 버튼 비활성 + 「8분 후 재생성 가능」 실시간 카운트다운 | ✓ |
| 단순 비활성 | 버튼 비활성만 + 툴팁으로 안내 | |

**User's choice:** 남은 시간 표시
**Notes:** None

---

## 콘텐츠 타입별 TTS 텍스트

| Option | Description | Selected |
|--------|-------------|----------|
| 대표 필드 1개씩 | 단어: reading, 문법: example_sentence, 퀴즈: question_text, 회화: 첫 turn | |
| 여러 필드 선택 가능 | reviewer가 드롭다운으로 TTS 대상 필드 선택 | ✓ |
| Claude 판단에 맡김 | 각 콘텐츠 타입에 가장 적합한 필드를 Claude가 결정 | |

**User's choice:** 여러 필드 선택 가능
**Notes:** 기본 필드 자동 선택 + reviewer가 변경 가능한 드롭다운

---

## Claude's Discretion

- TTS 가능 필드 목록 (각 콘텐츠 타입별)
- 미니 플레이어 세부 디자인
- 쿨다운 저장 위치 (서버 vs 클라이언트)
- 재생성 API 엔드포인트 설계
- 에러 핸들링 UI

## Deferred Ideas

None
