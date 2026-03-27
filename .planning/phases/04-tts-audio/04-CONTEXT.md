# Phase 4: TTS Audio - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

편집 화면에서 기존 TTS 오디오를 재생하고, 필요 시 재생성을 요청할 수 있다. 미니 오디오 플레이어, 재생성 확인 다이얼로그, 10분 항목별 쿨다운, 콘텐츠 타입별 TTS 필드 선택. FastAPI 어드민 TTS 엔드포인트 + 프론트엔드 플레이어 컴포넌트.

</domain>

<decisions>
## Implementation Decisions

### 오디오 플레이어 UI
- **D-01:** 미니 플레이어 — 재생 버튼 + 파형 애니메이션 + 재생성 버튼을 한 줄로 컴팩트하게. 편집 페이지 상단(제목 바로 아래)에 배치
- **D-02:** 오디오 없는 항목 — 플레이어 영역 회색 비활성 상태 + 「오디오 없음 — 생성」 버튼 표시. 재생성 유도

### 재생성 플로우
- **D-03:** 간단 확인 다이얼로그 — 「{항목명}의 TTS를 재생성하시겠습니까?」 + 확인/취소 버튼. 추가 정보 없이 간결하게
- **D-04:** 진행 상태 — 버튼이 로딩 스피너로 변하고 「생성 중...」 텍스트 표시. 완료 시 성공 토스트
- **D-05:** 완료 후 자동 재생 — 생성 완료 시 자동으로 새 오디오 재생. reviewer가 바로 확인 가능

### 쿨다운 정책
- **D-06:** 항목별 10분 쿨다운 — A 단어 재생성 후 10분간 A만 제한. B 단어는 바로 재생성 가능
- **D-07:** 남은 시간 실시간 표시 — 재생성 버튼 비활성 + 「8분 후 재생성 가능」 실시간 카운트다운 표시

### 콘텐츠 타입별 TTS 텍스트
- **D-08:** 여러 필드 선택 가능 — 각 콘텐츠 타입에서 TTS 가능한 필드 목록을 드롭다운으로 표시. reviewer가 원하는 필드를 선택하여 TTS 생성/재생성 가능
- **D-09:** 기본 필드 자동 선택 — 드롭다운에 기본값 설정 (단어: reading/word, 문법: example_sentence 등). reviewer가 변경하지 않으면 기본 필드로 TTS 생성

### Claude's Discretion
- TTS 가능 필드 목록 (각 콘텐츠 타입별 어떤 필드가 드롭다운에 포함될지)
- 미니 플레이어 컴포넌트 세부 디자인 (파형 vs 단순 재생바)
- 쿨다운 저장 위치 (서버 vs 클라이언트)
- 재생성 API 엔드포인트 설계 (기존 tts.py 패턴 확장 방식)
- 에러 핸들링 (TTS 생성 실패, GCS 업로드 실패 시 UI)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### TTS Infrastructure (기존 구현)
- `apps/api/app/routers/tts.py` — Vocabulary TTS 생성 + GCS 업로드 패턴 (확장 대상)
- `apps/api/app/models/tts.py` — TtsAudio 모델 (target_type, target_id, speed, audio_url)
- `apps/api/app/services/ai.py` — `generate_tts()` 함수 (ElevenLabs/Gemini)
- `apps/api/app/routers/kana_tts.py` — Kana TTS 패턴 (참고용)

### Content Models
- `apps/api/app/models/content.py` — Vocabulary, Grammar, ClozeQuestion, SentenceArrangeQuestion
- `apps/api/app/models/conversation.py` — ConversationScenario
- `apps/api/app/schemas/admin_content.py` — 상세 응답 스키마 (TTS 필드 목록 도출 대상)

### Phase 3 산출물 (직접 확장)
- `apps/admin/src/app/(admin)/vocabulary/[id]/page.tsx` — 편집 페이지 (플레이어 추가 대상)
- `apps/admin/src/app/(admin)/grammar/[id]/page.tsx` — 편집 페이지
- `apps/admin/src/app/(admin)/quiz/[id]/page.tsx` — 편집 페이지
- `apps/admin/src/app/(admin)/conversation/[id]/page.tsx` — 편집 페이지
- `apps/admin/src/lib/api/admin-content.ts` — API 클라이언트 (TTS 함수 추가)
- `apps/admin/src/components/content/review-header.tsx` — 상단 영역 (플레이어 배치 참고)

### Admin Infrastructure
- `apps/api/app/routers/admin_content.py` — 어드민 라우터 (TTS 엔드포인트 추가 대상)
- `apps/admin/src/components/ui/dialog.tsx` — shadcn Dialog (재생성 확인에 재사용)

### Project
- `.planning/ROADMAP.md` — Phase 4 성공 기준 3개
- `.planning/REQUIREMENTS.md` — TTS-01, TTS-02
- `.planning/phases/03-content-editing-review-workflow/03-CONTEXT.md` — Phase 3 결정사항
- `CLAUDE.md` — 프로젝트 컨벤션
- `.claude/rules/api.md` — API 코드 품질 규칙
- `.claude/rules/api-plane.md` — DDL/DML 거버넌스

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `apps/api/app/routers/tts.py` — vocab_tts() 패턴: TtsAudio 캐시 조회 → 없으면 generate_tts() → GCS 업로드 → DB 저장. 다른 콘텐츠 타입으로 확장 가능
- `apps/api/app/routers/tts.py:_upload_to_gcs()` — GCS 업로드 유틸 (재사용)
- `apps/api/app/routers/tts.py:_generating` — in-memory 중복 방지 set (확장 가능)
- `apps/admin/src/components/ui/dialog.tsx` — shadcn Dialog (재생성 확인 모달)
- `sonner` — 토스트 (성공/에러 표시)

### Established Patterns
- Phase 3: 편집 페이지에 ReviewHeader + AuditTimeline 배치 → 미니 플레이어도 같은 패턴으로 추가
- Phase 3: TanStack Query mutation + invalidation → TTS 재생성 mutation에 동일 패턴
- Phase 3: RejectReasonDialog 확인 모달 패턴 → 재생성 확인 다이얼로그에 유사 패턴
- TtsAudio.target_type: 'vocabulary' | 'kana' → 'grammar', 'quiz', 'conversation' 추가 필요

### Integration Points
- 4개 편집 페이지에 미니 플레이어 컴포넌트 추가
- `admin_content.py` 라우터에 TTS 재생성 엔드포인트 추가
- `admin-content.ts` API 클라이언트에 TTS 관련 함수 추가
- `messages/*.json` i18n 키 추가 (오디오 플레이어, 재생성, 쿨다운)

</code_context>

<specifics>
## Specific Ideas

- 콘텐츠 타입별 TTS 필드 드롭다운: reviewer가 어떤 텍스트로 TTS를 생성할지 선택 가능. 기본값은 자동 설정되지만 변경 가능
- 미니 플레이어는 편집 폼 제목 바로 아래, ReviewHeader 바로 아래에 배치

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-tts-audio*
*Context gathered: 2026-03-27*
