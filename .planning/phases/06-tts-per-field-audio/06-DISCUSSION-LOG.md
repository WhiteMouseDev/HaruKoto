# Phase 6: TTS Per-Field Audio - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-30
**Phase:** 06-tts-per-field-audio
**Areas discussed:** DB 마이그레이션 전략, API 응답 구조, GCS 경로 & 재생성 범위, 콘텐츠 타입별 필드 매핑

---

## DB 마이그레이션 전략

### 기존 데이터 처리

| Option | Description | Selected |
|--------|-------------|----------|
| field=null 유지 | 기존 레코드는 field=null, API에서 null은 레거시로 처리 | |
| 기본 필드로 매핑 | 마이그레이션에서 target_type별 기본값으로 채움 (vocabulary→reading 등) | ✓ |
| You decide | Claude 판단 | |

**User's choice:** 기본 필드로 매핑 (Claude 추천 수용 — 업계 표준 패턴)
**Notes:** NULL은 "없음"을 의미해야 하며, 기존 데이터는 실제로 기본 필드로 생성된 것이므로 매핑이 정확

### UniqueConstraint

| Option | Description | Selected |
|--------|-------------|----------|
| 맞음, 4컬럼 UK | (target_type, target_id, speed, field) | ✓ |
| You decide | Claude 판단 | |

**User's choice:** 4컬럼 UK (Claude 추천 수용)

### field 컬럼 타입

| Option | Description | Selected |
|--------|-------------|----------|
| Text 문자열 | 자유 형식 문자열, target_type과 동일 패턴 | ✓ |
| Enum (DB레벨) | PostgreSQL ENUM으로 필드 값 제한 | |
| You decide | Claude 판단 | |

**User's choice:** Text (Claude 추천 수용 — DB ENUM은 ALTER TYPE 마이그레이션 번거로움)

### 메인 앱 호환성

| Option | Description | Selected |
|--------|-------------|----------|
| 메인 앱 고려 필요 | tts.py 호환성도 이 Phase에서 함께 처리 | ✓ |
| 어드민만 변경 | 메인 앱은 문서로 넘김 | |
| You decide | Claude 판단 | |

**User's choice:** 이 Phase에서 함께 처리 (스키마 변경과 코드 호환을 분리하면 배포 사이 깨질 위험)

---

## API 응답 구조

### GET /tts 응답

| Option | Description | Selected |
|--------|-------------|----------|
| 필드별 맵 응답 | {audios: {reading: {audio_url, provider}, word: null, ...}} | ✓ |
| 필드별 개별 요청 | GET /tts?field=reading — N번 요청 필요 | |
| 배열 응답 | {audios: [{field: 'reading', audio_url: '...'}]} | |

**User's choice:** 필드별 맵 응답 (Claude 추천 수용 — REST 복합 리소스 표준 패턴)

### POST /tts/regenerate

| Option | Description | Selected |
|--------|-------------|----------|
| 단일 필드 유지 | 현재 패턴 유지, body에 field 이미 있음 | ✓ |
| You decide | Claude 판단 | |

**User's choice:** 단일 필드 유지 (Claude 추천 수용)

---

## GCS 경로 & 재생성 범위

### GCS 경로

| Option | Description | Selected |
|--------|-------------|----------|
| 필드 포함 경로 | tts/admin/{content_type}/{item_id}/{field}.mp3 | ✓ |
| 파일명 인코딩 | tts/admin/{content_type}/{item_id}_{field}.mp3 | |
| You decide | Claude 판단 | |

**User's choice:** 필드 포함 경로 (Claude 추천 수용 — GCS prefix-based hierarchy 표준)

### 기존 GCS 파일

| Option | Description | Selected |
|--------|-------------|----------|
| 마이그레이션 시 이동 | 기존 파일을 새 경로로 복사 | |
| 그대로 두기 | DB URL이 절대경로라 기존 그대로 동작 | ✓ |
| You decide | Claude 판단 | |

**User's choice:** 그대로 두기 (Claude 추천 수용 — write-path만 변경, read-path는 DB URL 신뢰)

---

## 콘텐츠 타입별 필드 매핑

### 필드 정의

| Option | Description | Selected |
|--------|-------------|----------|
| 현재 정의 충분 | vocabulary 3개, grammar/cloze/sentence_arrange/conversation 각 1개 | |
| grammar 확장 | grammar에 example_sentences 추가 (2개) | ✓ |
| conversation 확장 | conversation에 dialogue 추가 | |
| 전체 확장 | 여러 타입에 필드 추가 | |

**User's choice:** grammar에 example_sentences 추가 (Claude 추천 수용)

### Source of Truth

| Option | Description | Selected |
|--------|-------------|----------|
| 백엔드 정의 추가 | Python에도 TTS_FIELDS 추가, API에서 field 검증 | ✓ |
| 프론트엔드만 | 현재처럼 프론트엔드에만 정의 | |
| You decide | Claude 판단 | |

**User's choice:** 백엔드 정의 추가

---

## Claude's Discretion

- Alembic 마이그레이션 파일 세부 구현
- 메인 앱 tts.py 최소 호환성 수정
- useTtsPlayer 훅 필드별 상태 관리 방식
- TtsPlayer 컴포넌트 로딩/에러 상태
- Pydantic 스키마 세부 구조
- 테스트 범위

## Deferred Ideas

- BATCH-01: TTS 일괄 재생성 (Future requirement)
- GCS orphan cleanup job (재생성 시 이전 파일 정리)
