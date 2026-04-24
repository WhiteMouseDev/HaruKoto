# N5 파일럿 DB 실사 감사

> 작성일: 2026-04-24
> 종류: Audit (실행 계획 아님)
> 목적: v1.2 마일스톤 스코프 결정의 근거 데이터를 남긴다. Supabase MCP로 직접 조회한 프로덕션 DB 상태와 기존 계획 문서 간의 공백을 기록한다.
> 상관 문서:
> - `docs/operations/plans/n5-pilot-learning-flow-optimization-2026-04-23.md` (gap 목록)
> - `docs/operations/plans/n5-pilot-learning-flow-uat-checklist-2026-04-24.md` (UAT)
> - `docs/operations/plans/tts-implementation-roadmap.md` (vocab TTS만 포함)
> - `docs/domain/learning/lesson-flow-design.md` (6-step 설계)

## 1. 요약

N5 Part 1 (Ch.01~06, 30레슨)은 2026-03-21 이후 프로덕션 Supabase에 시드되어 `is_published=true` 상태로 **한 달 넘게 라이브**. 3명 유저가 실사용 중(총 8회 시도, 6회 완료). 콘텐츠 구조는 완결이나 운영 공백이 3건 확인됨:
1. **레슨 대화문 TTS 0건** — Step 2 가이드 리딩이 현재 무음
2. **어드민에 lesson/chapter 편집 UI 없음** — 원어민 검수 루프 진입 불가
3. **`meta.status: DRAFT`인 콘텐츠가 검수 없이 라이브** — 정책 미정 상태

## 2. 실사 방법

- 도구: Supabase MCP (`@supabase/mcp-server-supabase`, `--read-only` 모드)
- 프로젝트: `tdimppgykstgeykbnwal`
- 조회 시각: 2026-04-24 17시경 (KST)
- 모든 쿼리는 읽기 전용, DDL/DML 미실행

## 3. DB 상태 (증거)

### 3.1 시드 완결성

| 항목 | 값 |
|---|---|
| N5 챕터 수 | 6 (Ch.01~06 모두 `is_published=true`) |
| N5 레슨 수 | 30 (챕터당 5, 전부 `is_published=true`) |
| 콘텐츠 구조 | 레슨당 5문항 · 4턴 대화 · scene 존재 |
| 총 script 라인 | 120 (30레슨 × 평균 4턴) |
| Lesson-Item 링크 | 단어 528건, 문법 66건 |

**판단:** 콘텐츠 시드와 관계 설정은 완결.

### 3.2 실사용 데이터

| 지표 | 값 |
|---|---|
| 레슨 플레이한 유저 | 3명 |
| 총 시도 | 8회 |
| 완료 | 6회 |
| 진행 중 | 2회 |

**판단:** 매우 적은 실사용이지만 0은 아님. 살아있는 환경. 향후 유입 확대 시 실전 피드백 수집 가능한 상태.

### 3.3 SRS 사용 실태

| 지표 | 값 |
|---|---|
| `review_events` 총 레코드 | 4 |
| 기여 유저 수 | 1 |
| 첫 이벤트 | 2026-03-24 09:15 |
| 마지막 이벤트 | 2026-03-24 09:16 (**이후 0건**) |

**판단:** SRS 파이프라인은 시드 직후 하루만 동작한 흔적만 있고 한 달 동안 0건. 파이프라인이 끊어졌는지, 단지 유저 유입이 없었을 뿐인지는 별도 진단 필요.

### 3.4 TTS 생성 상태

| target_type | 총 레코드 | URL 있음 | 비고 |
|---|---:|---:|---|
| vocabulary | 40 | 40 | 단어 수준 TTS 일부 |
| kana | 1 | 1 | 테스트성으로 보임 |
| **lesson script** | **0** | **0** | **완전 공백** |

**판단:** 레슨 대화문 120줄에 대한 TTS가 **0건**. 설계(`lesson-flow-design.md` Step 2)의 "TTS 재생 + 번역 토글" 핵심 기능이 현재 무음 상태로 운영 중.

## 4. 기존 계획과의 갭

어제(2026-04-23) 작성된 `n5-pilot-learning-flow-optimization-2026-04-23.md`의 gap 목록(5절)은 **학습 플로우·상태 머신·SRS 연결**에 집중되어 있음. 아래 3건은 그 목록에 없음:

### 4.1 [신규 갭] 레슨 대화문 TTS 파이프라인 부재

- 기존 `tts-implementation-roadmap.md`는 vocabulary TTS (`POST /api/v1/vocab/tts`)만 다룸
- 레슨 `content_jsonb.reading.script[].voice_id`가 설계되어 있으나 실제 생성·저장·재생 경로 없음
- 영향: 학습 플로우 Step 2가 시각 전용으로 축소됨

### 4.2 [신규 갭] 어드민 lesson/chapter 편집 UI 부재

- `apps/admin/src/app/(admin)/` 라우트에 grammar/quiz/vocabulary/conversation 있으나 lesson/chapter 없음
- 결과: 원어민 검수 사이클이 JSON 수동 편집 → 재시드로만 가능 → 스케일 불가

### 4.3 [부분 일치] DRAFT 상태 콘텐츠 운영 정책 미정

- optimization 문서 4.4절에서 이슈 제기됨 (`DRAFT` 강제 publish 문제)
- 실사에서 확인: 30레슨 모두 `meta.status: DRAFT` 유지 + DB `is_published=true` + 한 달 노출 + 3명 실사용
- 결정 미이행 상태. `PILOT` 상태 도입 또는 정책 명시 필요

## 5. 권장 v1.2 스코프 (초안)

**주의:** v1.1 stabilization 수동 UAT 게이트(`docs/operations/release/v1.1-stabilization-checkpoint-2026-04-23.md`)가 아직 열려 있음. 아래는 UAT 종료 후 착수 후보.

### P0 — 레슨 대화문 TTS 파이프라인
- 기존 vocab TTS 파이프라인(`apps/api/app/routers/tts.py`, `apps/api/app/services/ai.py`) 재활용
- `target_type='lesson_script'` 추가 또는 별도 엔티티 설계
- GCS 경로: `tts/lesson/{lesson_id}/{line_index}.mp3`
- 생성 트리거: 레슨 seed 시 자동 + 수동 재생성 커맨드
- 모바일 재생: Step 2 `lesson_guided_reading_step.dart`에서 audioplayers 연동

### P1 — 어드민 lesson/chapter 편집 UI
- 기존 vocab 편집 패턴(`apps/admin/src/app/(admin)/vocabulary/[id]`) 참조
- FastAPI admin 엔드포인트 추가: GET/PATCH `/admin/lessons/{id}`, `/admin/chapters/{id}`
- 편집 대상: `title`, `subtitle`, `content_jsonb` (대화문·질문·해설), `is_published`
- 변경 이력: 기존 audit_logs 테이블 재활용

### P2 — DRAFT/PILOT 상태 정책 이행
- `meta.status`에 `PILOT` 값 도입, 시드 스크립트에서 `--publish-pilot` 플래그로 의도 명시
- 현재 라이브 콘텐츠는 `PILOT`으로 재지정 (DDL 없이 JSON 수정 + 재시드)

### P3 — 원어민 검수 사이클 (P1 완료 후)
- 30레슨 일괄 검수. 어드민에서 수정 → publish 토글 워크플로우
- 검수 기준: 일본어 자연스러움, 교수 순서, 번역 정확도, 문항 변별도
- 예상 공수: 레슨당 20~40분 × 30 = 10~20시간

### P4 — SRS 실사용 진단 (병렬 가능)
- 2026-03-24 이후 `review_events` 0건의 원인 조사
- 파이프라인 단절인지, 유저 유입 부재인지 구분

## 6. 열린 질문

1. **현재 3명의 실사용자가 누구인가?** (내부 테스트 계정인지, 실제 베타 유저인지)
2. **TTS 생성 비용 모델?** 30레슨 × 4턴 × Gemini TTS 1콜 = 120콜. Part 전체로는 계산 다름. 단가 확인 필요.
3. **어드민 편집 vs JSON 소스 SSOT 충돌 방지 전략?** 어드민에서 수정한 내용이 JSON 시드와 diverge하면 재시드 시 회귀. 동기화 정책 필요.
4. **기존 `tts-implementation-roadmap.md`와의 관계?** 해당 로드맵이 완료 상태인지, P0를 여기서 확장할지 정리 필요.

## 7. 다음 단계

1. v1.1 stabilization 수동 UAT 완료 → `v1.1.1` 태그 또는 의도적 deferral
2. 본 audit과 optimization 문서를 묶어 **v1.2 마일스톤 roadmap 초안** 작성 (`/gsd:new-milestone`)
3. P0/P1 각각 phase로 분리, 병렬 착수 가능 (백엔드+GCS vs 어드민 프론트)
