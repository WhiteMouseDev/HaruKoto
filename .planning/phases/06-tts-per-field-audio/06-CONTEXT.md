# Phase 6: TTS Per-Field Audio - Context

**Gathered:** 2026-03-30
**Status:** Ready for planning

<domain>
## Phase Boundary

TtsAudio DB 스키마에 field 컬럼을 추가하여 아이템당 필드별 독립 오디오를 저장·재생·재생성할 수 있도록 확장. Alembic 마이그레이션으로 기존 데이터를 기본 필드로 매핑하고, FastAPI API를 필드별 맵 응답으로 변경하며, 프론트엔드 훅/컴포넌트를 업데이트. 메인 앱(tts.py)의 하위 호환성도 보장.

</domain>

<decisions>
## Implementation Decisions

### DB 마이그레이션 전략
- **D-01:** TtsAudio 테이블에 `field` 컬럼(Text, NOT NULL) 추가. 업계 표준 3단계 마이그레이션: 1) field 컬럼 추가(nullable) → 2) 기존 데이터를 target_type별 기본 필드로 backfill (vocabulary→'reading', grammar→'pattern', cloze→'sentence', sentence_arrange→'japanese_sentence', conversation→'situation') → 3) NOT NULL 제약 + UniqueConstraint 변경
- **D-02:** UniqueConstraint를 `(target_type, target_id, speed, field)` 4컬럼으로 변경. 같은 아이템의 여러 필드에 각각 독립 오디오 저장 보장
- **D-03:** 메인 앱(tts.py) 호환성도 이 Phase에서 함께 처리. 스키마 변경과 코드 호환을 분리하면 배포 사이 깨질 위험. tts.py의 기존 쿼리가 필드별 복수 레코드에서 MultipleResultsFound 에러를 내지 않도록 수정

### API 응답 구조
- **D-04:** GET `/{content_type}/{item_id}/tts` 엔드포인트를 필드별 맵 응답으로 변경: `{audios: {reading: {audio_url, provider, created_at}, word: null, ...}}`. 복합 리소스의 하위 리소스를 맵으로 반환하는 REST 표준 패턴. 프론트엔드가 1회 요청으로 모든 필드 상태 파악
- **D-05:** POST `/tts/regenerate`는 현재 단일 필드 재생성 패턴 유지. body에 field 필드가 이미 있으므로 변경 없음. 응답에 regenerated field 정보 포함

### GCS 경로 & 재생성 범위
- **D-06:** 새로 생성하는 오디오의 GCS 경로: `tts/admin/{content_type}/{item_id}/{field}.mp3`. GCS/S3 prefix-based hierarchy 표준 패턴
- **D-07:** 기존 GCS 파일({item_id}.mp3)은 이동하지 않음. DB의 audio_url이 절대 URL이므로 기존 레코드는 그대로 동작. 재생성 시 자연스럽게 새 경로로 교체. 클라우드 스토리지 마이그레이션 정석: write-path만 변경, read-path는 DB URL 신뢰

### 콘텐츠 타입별 필드 매핑
- **D-08:** grammar에 `example_sentences` 필드 추가 (pattern + example_sentences = 2개). 나머지 콘텐츠 타입은 현재 tts-fields.ts 정의 유지:
  - vocabulary: reading, word, example_sentence (3개)
  - grammar: pattern, example_sentences (2개)
  - cloze: sentence (1개)
  - sentence_arrange: japanese_sentence (1개)
  - conversation: situation (1개)
- **D-09:** 백엔드(Python)에도 동일한 TTS_FIELDS 정의 추가. API가 유효한 field 값을 검증하는 단일 소스 오브 트루스 패턴. 프론트엔드와 백엔드 양쪽에서 동일한 필드 정의 유지

### Claude's Discretion
- Alembic 마이그레이션 파일 세부 구현 (revision ID, 트랜잭션 처리)
- 메인 앱 tts.py 호환성 수정 범위 (최소한의 변경)
- 프론트엔드 useTtsPlayer 훅의 필드별 상태 관리 방식 (단일 audioUrl → 필드별 맵)
- TtsPlayer 컴포넌트의 필드별 로딩/에러 상태 표시 방식
- Pydantic 스키마 변경 세부 구조 (AdminTtsResponse → AdminTtsMapResponse)
- pytest / Vitest 테스트 범위

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### DB & Migration
- `apps/api/app/models/tts.py` — TtsAudio 모델 (field 컬럼 추가 대상, 현재 UniqueConstraint 확인 필수)
- `apps/api/alembic/` — Alembic 마이그레이션 디렉토리 (DDL 권한은 Alembic ONLY)
- `.claude/rules/api-plane.md` — DDL/DML 거버넌스 정책

### Backend API
- `apps/api/app/routers/admin_content.py` — 어드민 TTS 엔드포인트 (GET /tts, POST /tts/regenerate, resolve_tts_text 함수)
- `apps/api/app/routers/tts.py` — 메인 앱 TTS 라우터 (호환성 수정 대상, _upload_to_gcs 유틸 재사용)
- `apps/api/app/services/ai.py` — generate_tts() 함수
- `apps/api/app/schemas/admin_content.py` — AdminTtsResponse, AdminTtsRegenerateRequest 스키마

### Content Models
- `apps/api/app/models/content.py` — Vocabulary, Grammar, ClozeQuestion, SentenceArrangeQuestion 모델 (필드 구조 확인)
- `apps/api/app/models/conversation.py` — ConversationScenario 모델

### Frontend
- `apps/admin/src/hooks/use-tts-player.ts` — TTS 재생/재생성 로직 훅 (필드별 맵으로 리팩토링 대상)
- `apps/admin/src/components/content/tts-player.tsx` — TTS 플레이어 컴포넌트 (필드별 독립 상태 표시로 업데이트)
- `apps/admin/src/lib/tts-fields.ts` — 콘텐츠 타입별 TTS 필드 정의 (grammar에 example_sentences 추가)
- `apps/admin/src/lib/api/admin-content.ts` — fetchTtsAudio, regenerateTts API 클라이언트 함수
- `apps/admin/src/components/content/regenerate-confirm-dialog.tsx` — 재생성 확인 다이얼로그 (재사용)

### 편집 페이지 (TtsPlayer 사용처)
- `apps/admin/src/app/(admin)/vocabulary/[id]/page.tsx`
- `apps/admin/src/app/(admin)/grammar/[id]/page.tsx`
- `apps/admin/src/app/(admin)/quiz/[id]/page.tsx`
- `apps/admin/src/app/(admin)/conversation/[id]/page.tsx`

### Phase 4 & 999.1 컨텍스트
- `.planning/phases/04-tts-audio/04-CONTEXT.md` — Phase 4 결정사항 (D-01~D-09, 미니 플레이어, 자동 재생 등)
- `.planning/phases/999.1-tts-field-ui-improvement/999.1-CONTEXT.md` — 999.1 결정사항 (드롭다운→리스트 UI)

### i18n
- `apps/admin/messages/ja.json` — tts 섹션 키
- `apps/admin/messages/en.json`
- `apps/admin/messages/ko.json`

### Project
- `.planning/ROADMAP.md` — Phase 6 성공 기준 4개
- `.planning/REQUIREMENTS.md` — TTS-03, TTS-04, TTS-05
- `CLAUDE.md` — 프로젝트 컨벤션
- `.claude/rules/api.md` — API 코드 품질 규칙
- `.claude/rules/api-plane.md` — DDL/DML 거버넌스

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `useTtsPlayer` 훅 — TanStack Query 기반 TTS 조회/재생성 로직. 현재 단일 audioUrl → 필드별 맵으로 리팩토링 필요
- `TtsPlayer` 컴포넌트 — Phase 999.1에서 리스트 UI로 리팩토링 완료. 필드별 독립 상태 표시로 업데이트 필요
- `RegenerateConfirmDialog` — 재생성 확인 다이얼로그 그대로 재사용
- `tts-fields.ts` — 콘텐츠 타입별 필드 정의. grammar에 example_sentences 추가 필요
- `_upload_to_gcs()` — GCS 업로드 유틸 (tts.py에서 import하여 재사용)
- `resolve_tts_text()` — 콘텐츠 모델에서 필드 텍스트 추출. grammar example_sentences 로직 이미 존재

### Established Patterns
- Phase 4: TanStack Query mutation + invalidation → TTS 재생성에 동일 패턴
- Phase 999.1: 세로 스택 리스트 UI, 각 필드 한 줄에 상태+재생+재생성 버튼
- `playingField`/`confirmField`가 string|null로 per-row 상태 추적 (Phase 999.1에서 확립)
- Admin API: Pydantic response_model로 응답 구조 강제

### Integration Points
- TtsAudio 모델: field 컬럼 추가 + UniqueConstraint 변경
- admin_content.py: GET /tts 응답을 맵 형태로 변경, POST /tts/regenerate는 GCS 경로만 변경
- tts.py (메인 앱): field 추가 후 기존 쿼리 호환성 보장
- useTtsPlayer 훅: 단일 audioUrl → 필드별 맵 (audios: Record<string, AudioInfo | null>)
- TtsPlayer 컴포넌트: hasAudio를 필드별로 분기
- 4개 편집 페이지: props 변경 없이 내부만 업데이트

</code_context>

<specifics>
## Specific Ideas

- 업계 표준 패턴 우선: 임시 우회(quick fix) 없이 정석 접근. 3단계 마이그레이션, REST 맵 응답, prefix-based GCS 경로
- 메인 앱 호환성을 같은 Phase에서 처리 — 스키마 변경과 코드 호환을 분리하면 배포 사이 깨질 위험
- grammar에 example_sentences TTS 추가로 문법 학습 품질 향상
- 백엔드에도 TTS_FIELDS 정의 추가하여 API 레벨에서 field 값 검증

</specifics>

<deferred>
## Deferred Ideas

- BATCH-01: TTS 일괄 재생성 (여러 항목 동시 재생성) — REQUIREMENTS.md에 Future로 분류
- GCS orphan cleanup job — 재생성 시 이전 경로 파일이 GCS에 남음. 별도 cleanup 작업으로 처리

</deferred>

---

*Phase: 06-tts-per-field-audio*
*Context gathered: 2026-03-30*
