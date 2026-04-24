# 테이블 Ownership 매핑

> **작성일**: 2026-03-23
> **목적**: 어떤 ORM이 어떤 테이블에 쓰기 권한을 가지는지 명시
> **규칙 요약**: `.claude/rules/api-plane.md`

---

## DDL Authority

| 항목 | 담당 |
|------|------|
| 스키마 변경 (DDL) | **Alembic** (`apps/api/alembic/`) |
| Prisma 동기화 | `pnpm db:sync` (db pull → format → generate) |
| Prisma DDL 명령어 | **차단됨** (`db:push`, `db:migrate` → 에러 반환) |

---

## 시딩 Ownership

### Prisma 시딩 (`packages/database/prisma/seed.ts`)

| 테이블 | 메서드 | 데이터 소스 |
|--------|--------|-----------|
| Vocabulary | `prisma.vocabulary.upsert()` | `data/vocabulary/n{1-5}-words.json` |
| Grammar | `prisma.grammar.upsert()` | `data/grammar/n{1-5}-grammar.json` |
| KanaCharacter | `prisma.kanaCharacter.upsert()` | `data/kana/*.json` |
| KanaLearningStage | `prisma.kanaLearningStage.upsert()` | `data/kana/stages-*.json` |
| ClozeQuestion | `prisma.clozeQuestion.upsert()` | `data/cloze/n{1-5}-cloze.json` |
| SentenceArrangeQuestion | `prisma.sentenceArrangeQuestion.upsert()` | `data/sentence-arrange/n{1-5}-arrange.json` |
| AiCharacter | `prisma.aiCharacter.createMany()` | `data/characters/ai-characters.json` |
| ConversationScenario | `prisma.conversationScenario.upsert()` | `data/scenarios/scenarios.json` |

**실행**: `cd packages/database && pnpm db:seed`

### SQLAlchemy 시딩 (`apps/api/app/seeds/`)

| 테이블 | 스크립트 | 메서드 |
|--------|---------|--------|
| Chapter, Lesson, LessonItemLink | `lessons.py` | `pg_insert().on_conflict_do_update()` |
| StudyStage | `study_stages.py` | `pg_insert().on_conflict_do_update()` |
| (SRS backfill) | `backfill_srs_state.py` | Raw SQL UPDATE |

**실행**: `cd apps/api && python -m app.seeds.lessons`

### 개발/스테이징 학습 콘텐츠 통합 시드

새 환경에서 학습 콘텐츠를 재현할 때는 root 명령을 사용한다.

```bash
DATABASE_URL="postgresql+asyncpg://user:pass@host:5432/db" pnpm seed:learning
```

이 명령은 아래 순서를 보장한다.

1. Prisma 정적 콘텐츠: vocabulary, grammar, kana, cloze, sentence arrange, scenarios, characters
2. SQLAlchemy 레슨 콘텐츠: N5 chapter, lesson, lesson item links
3. SQLAlchemy 학습 스테이지: N5 vocabulary, grammar, sentence stages

`DATABASE_URL`은 FastAPI/SQLAlchemy용 async URL이다. Prisma에 sync URL이 필요하면 `PRISMA_DATABASE_URL`을 별도로 지정한다.

---

## 런타임 쓰기 Ownership

### 범례
- **P** = Prisma (Web)
- **S** = SQLAlchemy (FastAPI/Mobile)
- `-` = 해당 없음

| 테이블 | Prisma 시딩 | Prisma 런타임 | SQLAlchemy 시딩 | SQLAlchemy 런타임 |
|--------|:-----------:|:------------:|:--------------:|:----------------:|
| **정적 콘텐츠** | | | | |
| Vocabulary | **P** | read | - | read |
| Grammar | **P** | read | - | read |
| KanaCharacter | **P** | read | - | read |
| KanaLearningStage | **P** | read | - | read |
| ClozeQuestion | **P** | read | - | read |
| SentenceArrangeQuestion | **P** | read | - | read |
| AiCharacter | **P** | read | - | read |
| ConversationScenario | **P** | read | - | read |
| **레슨/스테이지 (모바일 전용)** | | | | |
| Chapter | - | - | **S** | read |
| Lesson | - | - | **S** | read |
| LessonItemLink | - | - | **S** | read |
| StudyStage | - | - | **S** | read |
| TtsAudio | - | - | - | **S** |
| **사용자 데이터** | | | | |
| User | - | **P** | - | **S** |
| QuizSession | - | **P** | - | **S** |
| QuizAnswer | - | **P** | - | **S** |
| Conversation | - | **P** | - | S |
| WordbookEntry | - | **P** | - | S |
| DailyMission | - | **P** | - | S |
| DailyProgress | - | **P** | - | S |
| Notification | - | **P** | - | S |
| UserVocabProgress | - | **P** | - | **S** |
| UserGrammarProgress | - | read | - | **S** |
| UserKanaProgress | - | **P** | - | **S** |
| UserKanaStage | - | **P** | - | **S** |
| **모바일 전용 진행률** | | | | |
| UserLessonProgress | - | - | - | **S** |
| UserStudyStageProgress | - | - | - | **S** |
| **결제/구독** | | | | |
| Subscription | - | **P** | - | S |
| Payment | - | **P** | - | S |
| DailyAiUsage | - | **P** | - | S |
| PushSubscription | - | **P** | - | S |
| UserAchievement | - | **P** | - | S |
| UserCharacterUnlock | - | **P** | - | **S** |
| UserFavoriteCharacter | - | **P** | - | S |
| **내부 테이블** | | | | |
| alembic_version | - | @@ignore | - | Alembic 내부 |
| review_events | - | @@ignore | - | 파티션 테이블 |

---

## 동시 쓰기 안전성

현재 Web(Prisma)과 Mobile(SQLAlchemy)이 동일 테이블(User, QuizSession 등)에 쓰기를 합니다.

**현재 안전한 이유**:
- 동일 유저가 Web과 Mobile에서 동시에 같은 작업을 하는 시나리오가 없음
- Web은 웹 브라우저 유저, Mobile은 앱 유저가 별도로 사용

**향후 주의 사항**:
- Web/Mobile 동시 사용 시나리오가 생기면 API 단일화(FastAPI 수렴) 필요
- 트랜잭션 충돌 방지를 위해 optimistic locking 또는 API 게이트웨이 도입 검토

---

## 변경 절차

### 새 테이블 추가 시
1. `apps/api/app/models/`에 SQLAlchemy 모델 추가
2. `cd apps/api && uv run alembic revision --autogenerate -m "add table_name"`
3. `uv run alembic upgrade head`
4. `cd packages/database && pnpm db:sync`
5. 필요 시 `seed.ts` 또는 Python seed에 데이터 추가

### 기존 테이블 컬럼 변경 시
1. SQLAlchemy 모델 수정
2. Alembic migration 생성 + 적용
3. `pnpm db:sync`로 Prisma 동기화
4. Web 타입 체크: `cd apps/web && pnpm tsc --noEmit`
