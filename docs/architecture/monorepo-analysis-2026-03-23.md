# HaruKoto 모노레포 구조 분석 및 개선 보고서

> **작성일**: 2026-03-23
> **분석 방법**: Claude Code + Codex MCP 교차 검증 (3라운드 토론)
> **범위**: 전체 모노레포 (apps/4, packages/4, CI/CD, 보안, 아키텍처)

---

## 1. 현황 요약

### 모노레포 구성

| 구성요소 | 기술 스택 | 역할 |
|---------|----------|------|
| `apps/web` | Next.js 16.1 + React 19 + TypeScript | 메인 학습 웹앱 |
| `apps/api` | Python 3.12 + FastAPI + SQLAlchemy | 도메인 API 백엔드 |
| `apps/mobile` | Flutter 3.6 + Riverpod | iOS/Android 앱 |
| `apps/landing` | Next.js 16.1 (정적) | 마케팅 랜딩 페이지 |
| `packages/config` | TypeScript configs | 공유 TS 설정 |
| `packages/types` | TypeScript | 공유 타입 정의 |
| `packages/database` | Prisma ORM | DB 스키마 + 클라이언트 |
| `packages/ai` | Vercel AI SDK | AI 프로바이더 추상화 |

### 배포 인프라

- **Web/Landing**: Vercel (자동 배포)
- **API**: Google Cloud Run (asia-northeast3), GitHub Actions 자동 배포
- **Mobile**: 수동 빌드/배포
- **DB**: Supabase PostgreSQL

---

## 2. 아키텍처 Health Score

> Claude + Codex 합의 평가

| 항목 | 점수 | 평가 |
|------|:----:|------|
| 코드 구조 (Code Organization) | 7/10 | 모노레포/도메인 분리 양호. API 이중 구현이 복잡도 증가 |
| 타입 안전성 (Type Safety) | 5/10 | 앱 내부 strict 모드 적용. 플랫폼 간 계약 타입 수동 관리로 취약 |
| 테스트 커버리지 (Test Coverage) | 6/10 | 앱 레벨 테스트 존재. 패키지/계약 테스트 부재 |
| CI/CD 파이프라인 | 6/10 | 언어별 분리 파이프라인 양호. 경로 필터/스키마 게이트 부족 |
| 보안 (Security) | 5/10 | 기본 보안 갖춤. 모바일 cleartext, 운영 환경 리스크 존재 |
| 문서화 (Documentation) | 4/10 | 문서량 많으나 현행 아키텍처와 불일치 심각 |
| 의존성 관리 (Dependency Mgmt) | 7/10 | pnpm workspace + lockfile 기반 양호 |
| 스키마 일관성 (Schema Consistency) | **2/10** | Dual ORM + 모델 드리프트 — 가장 심각한 문제 |
| 확장성 (Scalability) | 6/10 | 기술 스택 확장 가능. 이중 API 유지비가 성장 저해 |
| 운영 준비도 (Production Readiness) | 5/10 | 배포 완료. 계약/스키마 일관성 이슈가 안정성 저해 |

### **종합: 5.3/10 (중간 이하 — 구조적 기술부채 정리 단계)**

---

## 3. 발견된 이슈 (우선순위별)

### P0 — 즉시 수정 필요

#### 3.1 Dual ORM 스키마 드리프트 (Critical)

**문제**: Web은 Prisma, API는 SQLAlchemy/Alembic을 사용하여 동일 DB를 이중 관리. 이미 실질적 드리프트 발생.

**SQLAlchemy에만 존재하는 모델 7개** (Prisma에 누락):

| 모델 | 용도 |
|------|------|
| `Chapter` | 챕터 관리 |
| `Lesson` | 레슨 콘텐츠 |
| `LessonItemLink` | 레슨-아이템 연결 |
| `StudyStage` | 학습 스테이지 |
| `TtsAudio` | TTS 오디오 캐시 |
| `UserLessonProgress` | 사용자 레슨 진행률 |
| `UserStudyStageProgress` | 스테이지 진행률 |

**근거**: Alembic에 Prisma 차이를 무시하는 로직까지 존재 (`alembic/env.py:20`)

**Codex 합의 수정안**:
1. **Alembic을 Schema Authority로 확정** — DDL 변경은 Alembic에서만 수행
2. **Prisma DDL 명령어 차단** — `db:migrate`, `db:push` 스크립트를 에러 반환으로 변경
3. **CI에 drift check 추가**:
   ```bash
   prisma migrate diff --exit-code \
     --from-url "$DATABASE_URL" \
     --to-schema-datamodel packages/database/prisma/schema.prisma
   ```
4. **Prisma 스키마 재동기화** — `prisma db pull`로 현재 DB 상태 반영

---

#### 3.2 Enum 불일치 (Critical)

**문제**: `@harukoto/types`, Prisma enum, SQLAlchemy enum, Flutter Dart enum이 모두 제각각.

| Enum | @harukoto/types | Prisma | SQLAlchemy | Flutter |
|------|----------------|--------|------------|---------|
| QuizType | 4종 (lowercase) | 7종 (UPPERCASE) | 7종 (UPPERCASE) | 수동 정의 |
| PartOfSpeech | 10종 (snake_case) | 11종 (UPPERCASE) | 11종 (UPPERCASE) | 수동 정의 |

**누락된 QuizType**: `KANA`, `CLOZE`, `SENTENCE_ARRANGE`
**누락된 PartOfSpeech**: `COUNTER`, `EXPRESSION`, `PREFIX`, `SUFFIX`

**Codex 합의 수정안**:
1. DB enum을 단일 소스로 지정 (Prisma/Alembic generated)
2. `@harukoto/types`의 수동 enum 정의 제거, generated types로 대체
3. 경계 계층(DB enum ↔ UI 문자열)에 매핑 함수 분리

---

#### 3.3 API Plane 이중 구현

**문제**: Web API Route(`src/app/api/v1/`)와 FastAPI가 대부분 중복 구현.

| 항목 | Web API | FastAPI |
|------|---------|---------|
| 경로 수 | 53개 | 73개 |
| 오퍼레이션 수 | 60개 | 83개 |
| **겹치는 오퍼레이션** | **56개** | **56개** |

**추가 발견**:
- HTTP 메서드 불일치: `GET /api/v1/vocab/tts` (Web) vs `POST /api/v1/vocab/tts` (FastAPI)
- Web 전용 op: `DELETE /api/v1/push/subscribe` (FastAPI는 POST만)
- Web route가 FastAPI를 프록시하지 않고 직접 DB/로직 처리

**Codex 합의 수정안**:
1. **FastAPI = Domain API 단일 소스**로 확정
2. **Next.js API Route = 얇은 BFF**(쿠키 auth 브릿지, 브라우저 전용 처리만)
3. 도메인 로직/DB 직접 접근은 FastAPI로 수렴

---

### P1 — 단기 수정 필요

#### 3.4 CI Path Filter 누락

**문제**: `packages/**` 변경 시 backend CI job이 트리거되지 않음.

```yaml
# 현재 ci.yml — backend 필터에 packages 미포함
backend:
  - 'apps/api/**'
# packages/database 변경은 backend에 영향주지만 CI 미실행
```

**수정안**:
```yaml
backend:
  - 'apps/api/**'
  - 'packages/database/**'
db_contract:  # 새 필터 추가
  - 'apps/api/alembic/**'
  - 'apps/api/app/models/**'
  - 'packages/database/prisma/**'
```

---

#### 3.5 Android Cleartext Traffic 활성화

**문제**: `AndroidManifest.xml`에 `android:usesCleartextTraffic="true"` — 릴리스 빌드에도 적용.

**수정안**: main manifest는 `false`, debug-only manifest에서 허용하거나 `network_security_config`로 localhost만 예외 처리.

---

#### 3.6 모바일-웹 API 계약 동기화 부재

**문제**: Flutter에서 FastAPI DTO를 수동 `fromJson`으로 재정의. OpenAPI codegen 없음.

**수정안**:
1. FastAPI OpenAPI를 단일 계약 소스로 확정
2. TypeScript client + Dart client를 OpenAPI에서 자동 생성
3. CI에 breaking-change 검사 추가

---

### P2 — 중기 개선

#### 3.7 패키지 테스트 부재

모든 shared package(`@harukoto/ai`, `@harukoto/types`, `@harukoto/database`)에 단위 테스트 없음.

**수정안**:
- `@harukoto/ai`: provider fallback/에러 처리 테스트
- `@harukoto/types`: enum 계약 스냅샷 테스트
- `@harukoto/database`: Prisma client smoke test

---

#### 3.8 라이브러리 패키지 빌드 미설정

`packages/ai`, `packages/types`가 `main: "./src/index.ts"`로 소스를 직접 참조. Next.js 내부 소비에서는 동작하지만 외부 런타임/툴에 취약.

**수정안**: `tsup` 또는 `tsc`로 `dist/` 빌드 + `exports` 필드 명시. 또는 source-consume 정책이면 `next.config.ts`에 `transpilePackages` 명시.

---

#### 3.9 TypeScript 버전 불일치

| 패키지 | 선언 버전 |
|--------|----------|
| apps/web | `^5` |
| apps/landing | `^5.9.3` |
| packages/* | `^5.8.0` |

**Codex 반박**: lockfile은 단일 `5.9.3`으로 해소됨. 실질적 문제 아님.

**수정안**: `pnpm.overrides`로 TS 버전 통일 + manifest range 정리.

---

#### 3.10 문서-코드 불일치

| 문서 내용 | 실제 상태 |
|----------|----------|
| `packages/ui` 존재 | 존재하지 않음 |
| Prisma 단독 ORM | Dual ORM (Prisma + SQLAlchemy) |
| PRD: Next.js API 단독 | FastAPI 병행 운영 |
| README 구조도 | API 앱 누락 |

**수정안**: CLAUDE.md, README.md를 현행 아키텍처에 맞게 업데이트.

---

#### 3.11 iOS OAuth 스킴 하드코딩

`Info.plist`에 Google/Kakao OAuth URL 스킴이 하드코딩.

**Codex 의견**: iOS URL scheme은 빌드 시점 고정값이 필요하여 보안 이슈보다 환경 분리/운영성 이슈.

**수정안**: dev/stg/prod flavor별 `xcconfig` 치환으로 값 분리.

---

## 4. 긍정적 평가 (잘 되어 있는 것)

| 항목 | 평가 |
|------|------|
| 의존성 그래프 | 순환 의존성 없음, 깔끔한 선형 구조 |
| TypeScript strict 모드 | 모든 TS 프로젝트에 적용 |
| Python strict typing | mypy strict + ruff 적용 |
| CI/CD 분리 | 언어별 독립 파이프라인 |
| 배포 자동화 | Vercel + Cloud Run 자동 배포 |
| Prisma singleton | globalThis 기반 개발/프로덕션 분리 |
| Turborepo 캐싱 | build, lint, test 캐시 설정 |
| 모니터링 | Sentry 전 플랫폼 통합 (web, api, mobile) |
| pnpm workspace | lockfile 기반 의존성 일관성 보장 |

---

## 5. 실행 로드맵

### Phase 1: 즉시 (이번 스프린트)

1. **Alembic authority 공식화**
   - Prisma `db:migrate`, `db:push` 차단
   - `prisma db pull`로 스키마 재동기화
   - CLAUDE.md, README 업데이트

2. **CI drift check 추가**
   - `prisma migrate diff --exit-code` CI job 추가
   - backend path filter에 `packages/database/**` 추가

3. **Android cleartext traffic 수정**
   - `network_security_config.xml` 도입

### Phase 2: 단기 (1-2주)

4. **API Plane 역할 분리 시작**
   - Web API Route 중 도메인 로직을 FastAPI 호출로 전환
   - BFF 패턴으로 점진 마이그레이션

5. **Enum 단일 소스 확립**
   - DB enum → 자동 생성 → 수동 정의 제거
   - 매핑 함수 도입

6. **문서 현행화**
   - `packages/ui` 참조 제거
   - Dual ORM/BFF 구조 반영

### Phase 3: 중기 (1개월)

7. **OpenAPI 계약 자동화**
   - FastAPI OpenAPI → TS/Dart client 자동 생성
   - CI breaking-change 검사

8. **패키지 테스트 추가**
   - ai, types, database 패키지 테스트 설정

9. **라이브러리 빌드 설정**
   - tsup 도입 또는 transpilePackages 명시

---

## 6. Codex 토론 요약

### 라운드 1: 이슈 평가 및 우선순위 재조정
- `.env` 커밋 이슈: P0→P2 (실제 tracked는 landing의 공개 URL뿐)
- Dual ORM: P2→P0으로 승격 (실제 드리프트 확인)
- Enum 불일치: P1→P0으로 승격 (범위 확장 — JlptLevel, UserGoal도 불일치)

### 라운드 2: 수정 방안 합의
- Schema authority: Alembic 확정 (Claude + Codex 합의)
- Prisma introspection: `db pull` + `migrate diff --exit-code` (CI 비파괴 검증)
- `@harukoto/types`: 분리 전략 (DB types vs API contract types)
- CI path filter: 경로 기반 + 전용 schema job으로 충분

### 라운드 3: 아키텍처 종합 평가
- Web API vs FastAPI: 순수 BFF가 아닌 중복 구현 (56/60 ops 겹침)
- 모바일 동기화: 수동 DTO, OpenAPI codegen 부재
- 종합 점수: 5.3/10

---

## 부록: 의존성 그래프

```
@harukoto/config (TypeScript 설정)
    ↑           ↑           ↑
    |           |           |
@harukoto/types  @harukoto/ai  @harukoto/database
                                     ↑
                                     |
                              apps/web (Prisma client)

apps/mobile → FastAPI (HTTP/REST)
apps/web → FastAPI (일부) + Prisma (직접)
apps/landing → 독립 (외부 의존 없음)
```

### 모델 커버리지 비교

```
Prisma 모델: 27개
SQLAlchemy 모델: 34개
겹침: 27개 (Prisma ⊂ SQLAlchemy)
SQLAlchemy only: 7개 (Chapter, Lesson, LessonItemLink, StudyStage, TtsAudio, UserLessonProgress, UserStudyStageProgress)
```
