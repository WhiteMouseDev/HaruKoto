# 하루코토 — 프로덕션 DB & 인프라 설계

> 최종 업데이트: 2026-03-05
> 상태: 설계 문서 (구현 전)

---

## 목차

1. [설계 원칙](#1-설계-원칙)
2. [학습 데이터 저장 전략](#2-학습-데이터-저장-전략)
3. [DB 스키마 설계 (현재 → 목표)](#3-db-스키마-설계-현재--목표)
4. [인프라 아키텍처 (목표)](#4-인프라-아키텍처-목표)
5. [GCP 서비스 통합 계획](#5-gcp-서비스-통합-계획)
6. [캐싱 전략](#6-캐싱-전략)
7. [데이터 파이프라인](#7-데이터-파이프라인)
8. [확장성 & 성능](#8-확장성--성능)
9. [보안 & 백업](#9-보안--백업)
10. [비용 계획](#10-비용-계획)

---

## 1. 설계 원칙

### 교육 앱 DB 설계의 핵심 질문: "학습 데이터를 DB에 넣을까?"

**결론: 하이브리드 전략**

| 데이터 유형 | 저장 위치 | 이유 |
|------------|----------|------|
| **학습 콘텐츠 원본** (단어, 문법, 가나) | DB (PostgreSQL) | 검색, 필터링, 페이지네이션, 관계 쿼리 필요 |
| **콘텐츠 시드 데이터** | JSON 파일 → DB seeding | 버전 관리, 리뷰, diff 가능. DB가 날아가도 복원 가능 |
| **사용자 학습 기록** | DB (PostgreSQL) | 트랜잭션 보장, 실시간 쿼리 필수 |
| **분석용 이벤트 로그** | BigQuery (향후) | 대량 데이터, 집계 쿼리에 최적화 |
| **정적 에셋** (오디오, 이미지) | Cloud Storage / CDN | DB에 바이너리 넣지 않음 |
| **AI 대화 히스토리** | DB (JSON 컬럼) → 향후 분리 | 현재 규모에서는 JSON으로 충분 |

### 왜 학습 콘텐츠를 DB에 넣는가?

교육 앱의 학습 데이터(단어, 문법 등)는 **단순 정적 파일이 아니다**:

```
1. 사용자 진도와 JOIN이 필요
   → "이 유저가 아직 안 본 N3 단어 중 복습 예정인 것" 같은 쿼리
   → DB에 없으면 매번 전체 JSON 로드 후 메모리에서 필터링 → 비효율

2. 검색/필터링이 빈번
   → JLPT 레벨별, 품사별, 태그별 필터링
   → DB 인덱스 활용 vs JSON 전체 스캔

3. 콘텐츠 업데이트 시 무중단 반영
   → DB UPDATE로 즉시 반영 vs 파일 변경 후 재배포

4. 통계 집계
   → "N3 단어 중 정답률 50% 이하인 단어 Top 10" → SQL 한 줄
```

**하지만 JSON 시드 파일도 유지하는 이유:**

```
1. Git 히스토리로 콘텐츠 변경 추적
2. 코드 리뷰를 통한 품질 관리
3. DB 초기화/복원 시 원본 데이터 보장
4. 로컬 개발 환경 세팅 용이
```

---

## 2. 학습 데이터 저장 전략

### 2-1. 콘텐츠 데이터 흐름

```
[콘텐츠 제작]
     │
     ▼
[JSON 시드 파일] ──git push──▶ [GitHub Repository]
(packages/database/data/)          │
     │                             │
     │  prisma db seed             │  CI/CD
     ▼                             ▼
[PostgreSQL]                  [Vercel 배포]
     │                             │
     │  Prisma ORM                 │
     ▼                             ▼
[API Routes] ◀──────────────▶ [클라이언트]
     │
     ▼
[Redis Cache] (향후)
```

### 2-2. 콘텐츠 규모 예측

| 레벨 | 단어 | 문법 | 한자 | 예문 | 예상 DB 크기 |
|------|------|------|------|------|-------------|
| N5 | 800 | 80 | 100 | 2,400 | ~5MB |
| N4 | 1,500 | 170 | 300 | 5,000 | ~10MB |
| N3 | 3,000 | 250 | 600 | 10,000 | ~20MB |
| N2 | 6,000 | 200 | 1,000 | 18,000 | ~35MB |
| N1 | 10,000 | 250 | 2,000 | 30,000 | ~55MB |
| **합계** | **~21,300** | **~950** | **~4,000** | **~65,400** | **~125MB** |

→ PostgreSQL 기준 전혀 부담 없는 크기. 별도 분리 불필요.

### 2-3. 사용자 데이터 규모 예측 (유저 10만 명 기준)

| 테이블 | 유저당 평균 row | 10만 유저 total | 예상 크기 |
|--------|---------------|----------------|----------|
| `user_vocab_progress` | ~500 | 5,000만 | ~4GB |
| `user_grammar_progress` | ~100 | 1,000만 | ~800MB |
| `quiz_sessions` | ~200 | 2,000만 | ~2GB |
| `quiz_answers` | ~2,000 | 2억 | ~15GB |
| `daily_progress` | ~180 | 1,800만 | ~1.5GB |
| `conversations` | ~50 | 500만 | ~3GB (JSON 포함) |
| `user_kana_progress` | ~200 | 2,000만 | ~1.5GB |
| **합계** | | | **~28GB** |

→ Supabase Pro 8GB RAM PostgreSQL로 충분 처리 가능 (~10만 유저까지)
→ 10만 유저 초과 시 read replica 또는 Cloud SQL 마이그레이션 검토

---

## 3. DB 스키마 설계 (현재 → 목표)

### 3-1. 현재 스키마 (23 테이블, 잘 설계됨)

```
[사용자]     User
             ├── QuizSession → QuizAnswer
             ├── Conversation
             ├── DailyProgress
             ├── DailyMission
             ├── UserVocabProgress
             ├── UserGrammarProgress
             ├── UserKanaProgress → UserKanaStage
             ├── UserAchievement
             ├── WordbookEntry
             ├── Notification
             ├── PushSubscription
             ├── UserFavoriteCharacter
             └── UserCharacterUnlock

[콘텐츠]    Vocabulary
             Grammar
             KanaCharacter → KanaLearningStage
             AiCharacter
             ConversationScenario
```

### 3-2. 현재 스키마 평가

**잘 된 점:**
- 모든 유저 테이블에 `onDelete: Cascade` → 유저 삭제 시 깔끔 정리
- SM-2 스페이스드 리피티션 필드 (`easeFactor`, `interval`, `nextReviewAt`) 적절
- 복합 인덱스 (`userId + nextReviewAt`, `userId + mastered`) 쿼리 최적화
- `@@unique` 제약으로 중복 데이터 방지
- `@@map`으로 Prisma 모델명과 DB 테이블명 분리 (snake_case)

**개선 필요:**
| 항목 | 현재 | 개선안 | 이유 |
|------|------|--------|------|
| `Conversation.messages` | JSON 컬럼 | 현 단계 유지, 10만 유저 초과 시 별도 테이블 분리 | JSON 컬럼은 개별 메시지 검색 불가, 현재 규모에서는 문제 없음 |
| `QuizSession.questionsData` | JSON 컬럼 | 유지 | 퀴즈 완료 후 읽기 전용이므로 JSON 적절 |
| `AiCharacter.personality` | 긴 텍스트 컬럼 | 유지 | 검색 대상 아님, 캐릭터 수 고정 |
| `quiz_answers` | 모든 답변 개별 저장 | 파티셔닝 검토 (향후) | 가장 빠르게 증가하는 테이블 |
| 한자(Kanji) 테이블 | 없음 | N3 이상 확장 시 추가 필요 | 현재 단어에 한자 포함, 별도 학습은 미지원 |

### 3-3. 향후 추가 예정 테이블

```prisma
// ==========================================
// Phase 2: 한자 학습 시스템
// ==========================================

model Kanji {
  id             String    @id @default(uuid()) @db.Uuid
  character      String    @unique        // "食"
  jlptLevel      JlptLevel @map("jlpt_level")
  onyomi         String[]                 // ["ショク", "ジキ"]
  kunyomi        String[]                 // ["た.べる", "く.う"]
  meaningKo      String    @map("meaning_ko") // "먹다, 음식"
  strokeCount    Int       @map("stroke_count")
  strokeOrder    Json?     @map("stroke_order")
  radicals       String[]                 // 부수
  relatedWords   String[]  @default([]) @map("related_words") @db.Uuid
  order          Int       @default(0)
  createdAt      DateTime  @default(now()) @map("created_at")

  userProgress UserKanjiProgress[]

  @@index([jlptLevel])
  @@map("kanji")
}

model UserKanjiProgress {
  id             String    @id @default(uuid()) @db.Uuid
  userId         String    @map("user_id") @db.Uuid
  kanjiId        String    @map("kanji_id") @db.Uuid
  correctCount   Int       @default(0) @map("correct_count")
  incorrectCount Int       @default(0) @map("incorrect_count")
  streak         Int       @default(0)
  easeFactor     Float     @default(2.5) @map("ease_factor")
  interval       Int       @default(0)
  nextReviewAt   DateTime? @map("next_review_at")
  lastReviewedAt DateTime? @map("last_reviewed_at")
  mastered       Boolean   @default(false)
  createdAt      DateTime  @default(now()) @map("created_at")
  updatedAt      DateTime  @updatedAt @map("updated_at")

  user  User  @relation(fields: [userId], references: [id], onDelete: Cascade)
  kanji Kanji @relation(fields: [kanjiId], references: [id], onDelete: Cascade)

  @@unique([userId, kanjiId])
  @@index([userId, nextReviewAt])
  @@index([userId, mastered])
  @@map("user_kanji_progress")
}

// ==========================================
// Phase 3: 결제 & 구독
// ==========================================

model Subscription {
  id              String   @id @default(uuid()) @db.Uuid
  userId          String   @map("user_id") @db.Uuid
  plan            String                // "monthly", "yearly"
  status          String                // "active", "cancelled", "expired"
  provider        String                // "stripe", "apple", "google"
  providerSubId   String?  @map("provider_sub_id")
  currentPeriodStart DateTime @map("current_period_start")
  currentPeriodEnd   DateTime @map("current_period_end")
  cancelledAt     DateTime? @map("cancelled_at")
  createdAt       DateTime @default(now()) @map("created_at")
  updatedAt       DateTime @updatedAt @map("updated_at")

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId])
  @@index([status])
  @@map("subscriptions")
}

model PaymentHistory {
  id             String   @id @default(uuid()) @db.Uuid
  userId         String   @map("user_id") @db.Uuid
  amount         Int                     // 원 단위
  currency       String   @default("KRW")
  provider       String                  // "stripe", "apple", "google"
  providerTxId   String?  @map("provider_tx_id")
  status         String                  // "succeeded", "failed", "refunded"
  createdAt      DateTime @default(now()) @map("created_at")

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId])
  @@map("payment_history")
}

// ==========================================
// Phase 4: 분석 이벤트 (로컬 버퍼 → BigQuery)
// ==========================================

model AnalyticsEvent {
  id        String   @id @default(uuid()) @db.Uuid
  userId    String?  @map("user_id") @db.Uuid
  event     String                // "quiz_completed", "word_learned", "conversation_started"
  properties Json    @default("{}")
  timestamp DateTime @default(now())
  synced    Boolean  @default(false) // BigQuery로 전송 완료 여부

  @@index([synced, timestamp])
  @@index([event, timestamp])
  @@map("analytics_events")
}
```

---

## 4. 인프라 아키텍처 (목표)

### 4-1. 목표 아키텍처 다이어그램

```
                    ┌──────────────────────────────────────┐
                    │          Client Layer                 │
                    │  [Flutter iOS/Android]  [Web Browser] │
                    └──────────────┬───────────────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────────────┐
                    │        Vercel Edge Network            │
                    │  CDN + Edge Functions + SSL           │
                    └──────────────┬───────────────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────────────┐
                    │      Next.js 16 Application          │
                    │  ┌────────┐ ┌─────┐ ┌──────────┐    │
                    │  │API     │ │SSR/ │ │Cron Jobs │    │
                    │  │Routes  │ │RSC  │ │(Vercel)  │    │
                    │  └───┬────┘ └──┬──┘ └────┬─────┘    │
                    └──────┼────────┼──────────┼──────────┘
                           │        │          │
              ┌────────────┼────────┼──────────┼──────────────┐
              │            ▼        ▼          ▼              │
              │  ┌─────────────────────────────────────────┐  │
              │  │           Supabase (Primary)             │  │
              │  │  ┌──────────┐  ┌──────────┐             │  │
              │  │  │PostgreSQL│  │  Auth     │             │  │
              │  │  │(PgBouncer│  │(OAuth)    │             │  │
              │  │  │ pooling) │  │           │             │  │
              │  │  └──────────┘  └──────────┘             │  │
              │  └─────────────────────────────────────────┘  │
              │                                               │
              │  ┌─────────────────────────────────────────┐  │
              │  │           GCP (보조 인프라)                │  │
              │  │                                         │  │
              │  │  ┌──────────────┐  ┌─────────────────┐  │  │
              │  │  │Memorystore   │  │ Vertex AI       │  │  │
              │  │  │(Redis)       │  │ (Gemini API)    │  │  │
              │  │  │- Rate Limit  │  │ - 텍스트 생성    │  │  │
              │  │  │- 캐시        │  │ - 음성 회화      │  │  │
              │  │  │- 세션 공유    │  │                 │  │  │
              │  │  └──────────────┘  └─────────────────┘  │  │
              │  │                                         │  │
              │  │  ┌──────────────┐  ┌─────────────────┐  │  │
              │  │  │Cloud Logging │  │ BigQuery        │  │  │
              │  │  │- 구조화 로그  │  │ - 사용자 분석    │  │  │
              │  │  │- 알림 설정    │  │ - GA4 export    │  │  │
              │  │  └──────────────┘  │ - 학습 패턴     │  │  │
              │  │                    └─────────────────┘  │  │
              │  │                                         │  │
              │  │  ┌──────────────┐  ┌─────────────────┐  │  │
              │  │  │Cloud Storage │  │ Cloud Tasks     │  │  │
              │  │  │- 오디오 파일  │  │ - 배치 알림      │  │  │
              │  │  │- 아바타 이미지│  │ - 통계 집계      │  │  │
              │  │  │- 콘텐츠 백업  │  │ - SRS 리마인더  │  │  │
              │  │  └──────────────┘  └─────────────────┘  │  │
              │  └─────────────────────────────────────────┘  │
              │                                               │
              │  ┌─────────────────────────────────────────┐  │
              │  │           Monitoring                     │  │
              │  │  [Sentry] ─ 에러 추적 + Session Replay   │  │
              │  │  [GCP Ops] ─ 로그 + 메트릭 + 알림        │  │
              │  └─────────────────────────────────────────┘  │
              └───────────────────────────────────────────────┘
```

### 4-2. 역할 분담 원칙

```
Vercel  = 배포, CDN, SSR, Edge Functions, Cron  (바꾸지 않음)
Supabase = PostgreSQL, Auth                      (바꾸지 않음)
GCP     = AI API, 캐시, 로깅, 분석, 스토리지      (새로 추가)
Sentry  = 에러 추적                               (바꾸지 않음)
```

**핵심: Vercel + Supabase는 건드리지 않고, GCP는 보조 인프라로만 활용**

---

## 5. GCP 서비스 통합 계획

### 5-1. Phase 1 — 즉시 도입 (Week 1~2)

#### Vertex AI (Gemini API 크레딧 전환)

```
현재: Google AI Studio API Key → Gemini 2.5 Flash
변경: Vertex AI Endpoint → 동일 모델, $950 크레딧 적용

변경 범위:
- packages/ai/src/provider.ts  → Vertex AI SDK로 교체
- apps/web/src/app/api/v1/chat/ → 엔드포인트 변경
- 환경변수: GOOGLE_GENERATIVE_AI_API_KEY → GCP 서비스 계정

주의:
- Gemini Live API (v1alpha)의 Vertex AI 호환성 확인 필요
- 호환 안 되면 Live API만 기존 유지, 텍스트 API만 Vertex로 전환
```

**예상 절감: 월 $80~150 AI API 비용 → $950 크레딧으로 6~12개월 커버**

#### Cloud Memorystore (Redis)

```
용도:
1. Rate Limiting (현재 인메모리 → 실제 작동하도록)
2. 프로필 캐시 (User 테이블 빈번 조회)
3. 학습 콘텐츠 캐시 (Vocabulary, Grammar 리스트)
4. 일일 미션 캐시

스펙: Basic M1 (1GB), asia-northeast3 (서울)
비용: ~$35/월
```

### 5-2. Phase 2 — 성장기 도입 (Month 2~3)

#### GA4 + BigQuery (사용자 분석)

```
용도:
- 학습 퍼널 분석 (온보딩 → 첫 퀴즈 → 첫 회화 → 리텐션)
- 일일/주간/월간 활성 사용자 (DAU/WAU/MAU)
- 기능별 사용률 (어떤 JLPT 레벨이 인기인지)
- 이탈 지점 파악

구현:
- GA4 gtag → 이미 NEXT_PUBLIC_GA_ID 설정됨, 이벤트 전송만 추가
- BigQuery export → GA4 자동 연동 (무료)

비용: 무료 (무료 티어 내)
```

#### Cloud Logging (구조화 로깅)

```
용도:
- API 요청/응답 로그 (Sentry 보완)
- AI 대화 품질 로그 (응답 시간, 토큰 사용량)
- 퀴즈 정답률 트렌드
- 비정상 패턴 감지 (비정상적 XP 획득 등)

구현:
- pino logger + @google-cloud/logging transport
- 기존 console.log → logger.info/warn/error 교체

비용: 무료 (50GB/월 무료 티어)
```

### 5-3. Phase 3 — 스케일링 (Month 4+)

#### Cloud Tasks (백그라운드 작업)

```
용도:
- 스페이스드 리피티션 알림 배치 발송
- 주간 학습 리포트 생성
- 비활성 유저 리인게이지먼트 알림
- 업적 달성 체크 (비동기)

현재: Vercel Cron (1일 1회, 단순)
변경: Cloud Tasks + Cloud Scheduler → 복잡한 배치 처리

비용: 무료 (100만 요청/월 무료)
```

#### Cloud Storage (정적 에셋)

```
용도:
- 단어/문법 오디오 파일 (TTS 생성 후 저장)
- 캐릭터 아바타 이미지
- 사용자 프로필 이미지 (향후)
- DB 백업 스냅샷

현재: public/ 폴더에 정적 배포
변경: 오디오 등 대용량 에셋만 Cloud Storage + CDN

비용: ~$5/월 (5GB 무료 + 소량 트래픽)
```

---

## 6. 캐싱 전략

### 6-1. 캐시 계층 설계

```
[클라이언트]
  └─ TanStack Query (메모리 캐시, staleTime 기반)
       │
[Vercel Edge]
  └─ Cache-Control 헤더 (정적 콘텐츠)
       │
[Redis (Memorystore)]
  └─ 서버 사이드 캐시 (프로필, 콘텐츠 리스트)
       │
[PostgreSQL]
  └─ 원본 데이터 (source of truth)
```

### 6-2. 캐시 대상 & TTL

| 데이터 | 캐시 위치 | TTL | 무효화 조건 |
|--------|----------|-----|------------|
| 유저 프로필 | Redis | 5분 | 프로필 수정, XP 변경 |
| 단어 목록 (레벨별) | Redis | 1시간 | 콘텐츠 업데이트 (희귀) |
| 문법 목록 (레벨별) | Redis | 1시간 | 콘텐츠 업데이트 |
| 가나 문자 | Redis | 24시간 | 거의 변경 없음 |
| AI 캐릭터 목록 | Redis | 30분 | 캐릭터 추가/수정 |
| 일일 미션 | Redis | 자정까지 | 미션 완료/보상 수령 |
| 대시보드 통계 | Redis | 3분 | 학습 활동 발생 |
| 복습 대상 단어 | TanStack Query만 | 30초 | 복습 완료 |
| 퀴즈 세션 | 캐시 안 함 | - | 실시간 데이터 |

### 6-3. Redis 키 네이밍 컨벤션

```
user:{userId}:profile          → 유저 프로필
user:{userId}:stats            → 대시보드 통계
user:{userId}:missions:{date}  → 일일 미션
content:vocab:{level}:{page}   → 단어 목록
content:grammar:{level}:{page} → 문법 목록
content:kana:{type}            → 가나 문자
content:characters             → AI 캐릭터 목록
rate:{type}:{identifier}       → Rate limiting 카운터
```

---

## 7. 데이터 파이프라인

### 7-1. 콘텐츠 업데이트 파이프라인

```
[콘텐츠 제작/수정]
     │
     ▼
[JSON 파일 수정] ──PR 생성──▶ [코드 리뷰]
     │                            │
     │                       승인 + Merge
     │                            │
     ▼                            ▼
[prisma db seed]            [Vercel 배포]
     │                            │
     ▼                            ▼
[PostgreSQL 업데이트]        [앱 배포 완료]
     │
     ▼
[Redis 캐시 무효화]
(content:* 키 삭제)
```

### 7-2. 사용자 학습 데이터 흐름

```
[사용자 학습 행동]
     │
     ├──▶ [PostgreSQL] ── 즉시 저장 (트랜잭션)
     │         │
     │         ├── user_vocab_progress (SRS 업데이트)
     │         ├── daily_progress (일일 통계)
     │         ├── quiz_sessions/answers (퀴즈 기록)
     │         └── conversations (대화 기록)
     │
     ├──▶ [Redis] ── 캐시 무효화
     │         │
     │         ├── user:{id}:stats (무효화)
     │         └── user:{id}:missions:{date} (무효화)
     │
     └──▶ [GA4] ── 이벤트 전송 (비동기)
               │
               └──▶ [BigQuery] ── 자동 export (일 1회)
```

### 7-3. N3~N1 콘텐츠 확장 계획

```
Phase 1 (현재): N5 + N4 (완료)
  └─ 800 + 1,500 = 2,300 단어
  └─ 80 + 170 = 250 문법

Phase 2 (다음): N3 추가
  └─ +3,000 단어, +250 문법, +600 한자
  └─ Kanji 테이블 신규 생성
  └─ 예상 작업량: 2~3주 (AI 보조 생성 + 수동 검수)

Phase 3: N2 추가
  └─ +6,000 단어, +200 문법, +1,000 한자
  └─ 예상 작업량: 3~4주

Phase 4: N1 추가
  └─ +10,000 단어, +250 문법, +2,000 한자
  └─ 예상 작업량: 4~6주
  └─ N1은 프리미엄 전용 콘텐츠 가능
```

---

## 8. 확장성 & 성능

### 8-1. 병목 지점 분석 & 대응

| 병목 | 임계점 | 대응 | 시기 |
|------|--------|------|------|
| DB 커넥션 풀 | PgBouncer 동시 20 | Supabase Pro (50 커넥션) | 현재 충분 |
| `quiz_answers` 테이블 크기 | 1억 row (~10GB) | 날짜 기반 파티셔닝 | 유저 5만+ |
| `conversations.messages` JSON 크기 | 개별 row 10MB+ | 메시지 별도 테이블 분리 | 유저 10만+ |
| 동시 AI 요청 | Gemini API rate limit | 큐잉 + 재시도 로직 | 동시 접속 100+ |
| Redis 메모리 | 1GB 초과 | M2 (4GB) 업그레이드 | 유저 5만+ |

### 8-2. 쿼리 최적화 체크리스트

```sql
-- 가장 빈번한 쿼리 패턴과 인덱스 매핑:

-- 1. 복습 대상 단어 조회 (매 학습 세션)
SELECT * FROM user_vocab_progress
WHERE user_id = $1 AND next_review_at <= NOW() AND mastered = false
ORDER BY next_review_at
LIMIT 20;
→ 인덱스: @@index([userId, nextReviewAt]) ✅

-- 2. 대시보드 통계 (매 앱 진입)
SELECT * FROM daily_progress
WHERE user_id = $1 AND date >= $2
ORDER BY date DESC;
→ 인덱스: @@index([userId, date]) ✅

-- 3. 단어 목록 (레벨별 브라우징)
SELECT * FROM vocabularies
WHERE jlpt_level = $1
ORDER BY "order"
LIMIT 50 OFFSET $2;
→ 인덱스: @@index([jlptLevel]) ✅
→ 개선: ORDER BY + LIMIT 패턴에 복합 인덱스 추가 고려
   @@index([jlptLevel, order])

-- 4. 미읽은 알림 카운트 (매 앱 진입)
SELECT COUNT(*) FROM notifications
WHERE user_id = $1 AND is_read = false;
→ 인덱스: @@index([userId, isRead]) ✅
```

### 8-3. DB 마이그레이션 전략

```
현재: prisma db push (Supabase 직접 반영)
목표: prisma migrate (마이그레이션 파일 기반)

이유:
- db push는 개발 편의용, 프로덕션에서는 마이그레이션 히스토리 필요
- 롤백 가능성, 팀 협업 시 스키마 충돌 방지
- CI/CD에서 자동 마이그레이션 실행

전환 시점: 팀원 추가 또는 스키마 변경 빈도 증가 시
```

---

## 9. 보안 & 백업

### 9-1. 데이터 보안

| 영역 | 현재 | 목표 |
|------|------|------|
| **전송 암호화** | HTTPS (Vercel SSL) ✅ | 유지 |
| **저장 암호화** | Supabase 기본 (AES-256) ✅ | 유지 |
| **인증** | Supabase Auth + OAuth ✅ | 유지 |
| **API 인가** | 세션 기반 userId 검증 ✅ | 유지 |
| **입력 검증** | Zod 스키마 ✅ | 유지 |
| **Rate Limiting** | 인메모리 (미작동) ❌ | Redis 기반으로 교체 |
| **SQL Injection** | Prisma ORM (안전) ✅ | 유지 |
| **민감 데이터** | 비밀번호 미저장 (OAuth) ✅ | 유지 |
| **PII 접근 로그** | 없음 ❌ | Cloud Logging으로 감사 로그 추가 |

### 9-2. 백업 전략

```
[Supabase 자동 백업]
├── Point-in-Time Recovery: Pro 플랜 기본 (7일)
├── 일일 백업: 자동
└── 복원: Supabase 대시보드에서 1클릭

[추가 백업 (향후)]
├── Cloud Storage에 주간 pg_dump
├── 콘텐츠 시드 데이터: Git 저장소 (항상 최신)
└── 환경변수: 1Password 등 시크릿 매니저
```

### 9-3. 재해 복구 (DR)

```
RTO (Recovery Time Objective): 1시간
RPO (Recovery Point Objective): 24시간

시나리오별 대응:
1. Supabase 장애 → Supabase 상태 페이지 모니터링, 대기
2. DB 데이터 손실 → PITR로 복원 (7일 이내)
3. 시드 데이터 필요 → git clone + prisma db seed
4. Vercel 장애 → 다른 리전 배포 또는 대기 (드묾)
5. GCP Redis 장애 → 앱은 Redis 없이도 동작 (캐시 미스 → DB 직접 조회)
```

---

## 10. 비용 계획

### 10-1. 현재 월간 비용

| 서비스 | 비용 | 비고 |
|--------|------|------|
| Vercel Pro | $20/월 | 웹앱 + 랜딩 |
| Supabase Pro | $25/월 | PostgreSQL + Auth |
| Google AI API | $80~150/월 | Gemini 2.5 Flash (사용량 비례) |
| Sentry | $0 (무료 티어) | 5K 이벤트/월 |
| 도메인 | ~$2/월 | harukoto.co.kr |
| **합계** | **~$130~200/월** | |

### 10-2. GCP 도입 후 비용 (목표)

| 서비스 | 비용 | 크레딧 적용 |
|--------|------|------------|
| Vercel Pro | $20/월 | - |
| Supabase Pro | $25/월 | - |
| Vertex AI (Gemini) | $80~150/월 | **$950 크레딧** |
| Cloud Memorystore | $35/월 | **$950 크레딧** |
| Cloud Logging | $0 | 무료 티어 |
| BigQuery + GA4 | $0 | 무료 티어 |
| Cloud Tasks | $0 | 무료 티어 |
| Cloud Storage | ~$5/월 | **$950 크레딧** |
| Sentry | $0 | 무료 티어 |
| 도메인 | ~$2/월 | - |

### 10-3. $950 크레딧 최적 배분

```
총 크레딧: $950

[1] Vertex AI (Gemini API)     $600  ── AI 호출 비용 6~8개월분
[2] Cloud Memorystore (Redis)  $250  ── Redis 7개월 운영
[3] Cloud Storage              $50   ── 에셋 스토리지 10개월+
[4] 실험/버퍼                   $50   ── Cloud Run 프로토타이핑 등
                                ────
                                $950

크레딧 소진 후 (약 7~8개월 후):
- Vertex AI → 유지 (수익으로 충당) 또는 AI Studio로 복귀
- Redis → 유지 ($35/월, 필수 인프라)
- 나머지 → 무료 티어 내
```

### 10-4. 유저 규모별 비용 예측

| 유저 수 | Supabase | AI API | Redis | 기타 | 합계 |
|---------|----------|--------|-------|------|------|
| ~1,000 | $25 | $80 | $35 | $22 | ~$162/월 |
| ~10,000 | $25 | $300 | $35 | $22 | ~$382/월 |
| ~50,000 | $75 (Team) | $800 | $70 (M2) | $30 | ~$975/월 |
| ~100,000 | $75 | $1,500 | $70 | $50 | ~$1,695/월 |

→ 프리미엄 구독 (월 4,900원) 유저 50명이면 월 $170 수익으로 인프라 비용 커버 시작

---

## 부록: 비추천 사항

| 접근 | 왜 안 되는가 |
|------|-------------|
| 학습 데이터를 JSON 파일로만 관리 | 유저 진도와 JOIN 불가, 검색/필터링 비효율 |
| Cloud SQL로 마이그레이션 | Supabase Auth와 분리됨, 이중 관리, 비용 증가 |
| Firebase 도입 | Supabase와 완전 중복, 마이그레이션 비용만 큼 |
| GKE (Kubernetes) | 교육 앱에 K8s는 오버엔지니어링 |
| 모든 것을 GCP로 | Vercel의 DX와 CDN을 포기할 이유 없음 |
| 대화 메시지를 별도 DB (MongoDB 등) | 현재 규모에서 불필요한 복잡도. 10만 유저 초과 시 재검토 |
