# 웹 API vs FastAPI 백엔드 비교 분석

**작성일**: 2026-03-12
**분석 대상**: 웹(Next.js) API를 정답 기준으로 FastAPI 구현의 정확도 검증

---

## 📊 요약

- **총 엔드포인트**: 53개 (웹 API 기준)
- **구현됨**: 48개 ✅
- **누락**: 5개 ❌
- **불일치**: 15개 (CRITICAL: 1, HIGH: 7, MEDIUM: 4, LOW: 3)

**전체 호환성**: 약 85% (48/53)

---

## 🔴 누락된 엔드포인트 (5개)

### 1. POST /api/auth/ensure-user ❌ CRITICAL
- **우선순위**: 높음
- **원인**: 웹에서는 Supabase Auth 후 자동 호출하는 내부 엔드포인트
- **FastAPI 영향**: 모바일 앱이 이 엔드포인트를 호출할 수 없음
- **수정 방안**: FastAPI에서 `/api/v1/auth/ensure-user` 엔드포인트 추가
  ```python
  @router.post("/auth/ensure-user")
  async def ensure_user(user: User = Depends(get_current_user)):
      return UserProfile.model_validate(user)
  ```

### 2. POST /api/v1/user/avatar ❌ HIGH
- **웹 구현**: multipart/form-data로 파일 업로드 (GCS)
- **FastAPI 구현**: PATCH `/api/v1/user/avatar`로 avatarUrl(문자열)만 받음
- **차이점**: 웹은 파일 업로드 → 자동 GCS 저장, FastAPI는 URL만 저장
- **수정 방안**: FastAPI에 POST `/api/v1/user/avatar` (multipart/form-data) 엔드포인트 추가

### 3. DELETE /api/v1/user/account ❌ CRITICAL
- **원인**: 웹 문서에는 있지만 FastAPI에 전혀 없음
- **기능**: 계정 완전 삭제 (GCS 파일 + Prisma CASCADE + Supabase Auth)
- **수정 방안**: FastAPI에서 DELETE `/api/v1/user/account` 구현

### 4. POST /api/v1/vocab/tts ❌ MEDIUM
- **웹 구현**: `{ word, reading }` 입력 → audioUrl 반환
- **FastAPI 구현**: POST `/api/v1/vocab/tts` → `{ id }` 입력 → audioUrl 반환
- **차이점**: 웹은 단어 텍스트를 입력, FastAPI는 vocabulary_id 입력
- **수정 방안**: FastAPI 구현이 더 효율적이지만, 문서상 이름과 입력 형식이 다름

### 5. POST /api/v1/push/subscribe ❌ LOW
- **구현 상태**: FastAPI 문서에는 있지만 실제 라우터에 없음
- **원인**: 웹에서 Web Push API용 (선택적 기능)
- **심각도**: 낮음 (푸시 알림은 선택적)

---

## 🟡 필드 불일치 (15개)

### Authentication

#### POST /api/v1/auth/onboarding - ⚠️ MEDIUM
- **웹 요청**: `{ nickname, jlptLevel, goal, dailyGoal }`
- **FastAPI 요청**: `{ nickname, jlptLevel, goal?, dailyGoal=10 }`
- **웹 응답**: `{ profile: UserObject }`
- **FastAPI 응답**: `{ success: bool, user: UserProfile }`
- **문제**: 응답 래퍼 구조 다름 (`profile` vs `success+user`)
- **영향도**: MEDIUM (모바일에서 `response.profile` 접근하면 undefined)
- **수정 방안**: FastAPI 응답을 웹과 동일하게 변경
  ```python
  class OnboardingResponse:
      profile: UserProfile  # user → profile로 변경
  ```

---

### Quiz

#### POST /api/v1/quiz/start - ⚠️ MEDIUM
- **웹 응답 question 필드**:
  ```json
  {
    "questionId": "string",      // ← 웹에서는 questionId
    "questionText": "string",    // ← 웹에서는 questionText
    "questionSubText": "string | null",
    "hint": "string | null",
    "options": [{ "id", "text" }],
    "correctOptionId": "string"
  }
  ```
- **FastAPI 응답**:
  ```json
  {
    "id": "UUID",                // ← FastAPI는 id
    "type": "string",            // ← FastAPI는 type (VOCABULARY|GRAMMAR|...)
    "question": "string",        // ← FastAPI는 question
    "options": [{ "id", "text" }],
    "correctOptionId": "string"
  }
  ```
- **필드 매핑 부재**:
  - 웹의 `questionId` ↔ FastAPI의 `id`
  - 웹의 `questionText` ↔ FastAPI의 `question`
  - 웹의 `questionSubText` (없음) ↔ FastAPI의 `type`
  - arrange/cloze 모드의 추가 필드 (koreanSentence, japaneseSentence, tokens, explanation, sentence, translation) 부분적 구현
- **영향도**: MEDIUM (필드명이 다르면 모바일에서 파싱 실패)
- **수정 방안**: FastAPI의 QuizQuestion 스키마를 웹과 정확히 맞추기

#### GET /api/v1/quiz/resume - ⚠️ HIGH
- **웹 요청**: POST (body: `{ sessionId }`)
- **FastAPI 요청**: GET (쿼리 파라미터 없음)
- **차이**: HTTP 메서드 다름 (POST vs GET)
- **영향도**: HIGH (모바일이 GET으로 요청하면 웹은 POST 기대)
- **수정 방안**: FastAPI를 POST로 변경하거나 웹을 GET으로 통일

#### GET /api/v1/quiz/recommendations - ⚠️ LOW
- **웹 응답**:
  ```json
  {
    "reviewDueCount": number,
    "newWordsCount": number,
    "wrongCount": number,
    "lastReviewedAt": "ISO string | null"
  }
  ```
- **FastAPI 응답**:
  ```json
  {
    "recommendations": [{
      "type": "review|normal",
      "quizType": "VOCABULARY|GRAMMAR",
      "count": int,
      "reason": str
    }]
  }
  ```
- **차이**: 응답 구조 완전히 다름
- **영향도**: LOW (기능은 동작하지만 데이터 구조 다름)
- **수정 방안**: FastAPI 응답 구조를 웹과 맞추기

---

### Chat

#### POST /api/v1/chat/end - ⚠️ HIGH
- **웹 응답**:
  ```json
  {
    "success": true,
    "feedbackSummary": { /* 상세 피드백 */ },
    "xpEarned": number,
    "events": [{ type, title, body, emoji }]
  }
  ```
- **FastAPI 응답**:
  ```json
  {
    "success": true,
    "feedbackSummary": dict | null,
    "xpEarned": int,
    "events": list
  }
  ```
- **문제**: feedbackSummary 구조 명확하지 않음 (FastAPI에서 null 가능)
- **수정 방안**: FastAPI에서 feedbackSummary 구조를 명시적으로 정의하기

#### GET /api/v1/chat/characters - ⚠️ HIGH
- **웹 응답**: 목록 직접 반환
  ```json
  {
    "characters": [{ ... }, { ... }]
  }
  ```
- **FastAPI 구현**: 배열 직접 반환 (래퍼 없음)
  ```json
  [{ ... }, { ... }]
  ```
- **문제**: 웹은 `{ characters: [...] }` 형태, FastAPI는 배열만 반환
- **영향도**: HIGH (모바일이 `response.characters`로 접근하면 undefined)
- **수정 방안**: FastAPI 응답을 래퍼로 감싸기
  ```python
  return { "characters": [...] }
  ```

#### GET /api/v1/chat/characters/stats - ⚠️ HIGH
- **웹 응답**:
  ```json
  {
    "characterStats": {
      "characterId": number,
      ...
    }
  }
  ```
- **FastAPI 응답**:
  ```json
  {
    "stats": { "characterId": int }
  }
  ```
- **문제**: 응답 필드명 다름 (`characterStats` vs `stats`)
- **영향도**: HIGH
- **수정 방안**: FastAPI를 `characterStats`로 변경

#### GET /api/v1/chat/characters/favorites - ⚠️ HIGH
- **웹 응답**:
  ```json
  {
    "favoriteIds": ["string", ...]
  }
  ```
- **FastAPI 응답**:
  ```json
  {
    "favorites": ["string", ...]
  }
  ```
- **문제**: 필드명 다름 (`favoriteIds` vs `favorites`)
- **영향도**: HIGH
- **수정 방안**: FastAPI를 `favoriteIds`로 변경

#### GET /api/v1/chat/history - ⚠️ MEDIUM
- **웹 응답 항목**:
  ```json
  {
    "id": "string",
    "type": "TEXT|VOICE",
    "createdAt": "ISO string",
    "endedAt": "ISO string",
    "messageCount": number,
    "overallScore": number | null,
    "scenario": { "title", "titleJa", "category", "difficulty" } | null,
    "character": { "id", "name", "nameJa", "avatarEmoji", "avatarUrl" } | null
  }
  ```
- **FastAPI 응답 항목**:
  ```json
  {
    "id": "string",
    "scenarioTitle": "string | null",     // ← 웹은 scenario.title
    "category": "string | null",           // ← 웹은 scenario.category
    "difficulty": "string | null",         // ← 웹은 scenario.difficulty
    "characterName": "string | null",      // ← 웹은 character.name
    "characterEmoji": "string | null",     // ← 웹은 character.avatarEmoji
    "messageCount": int,
    "overallScore": float | null,
    "createdAt": "ISO",
    "endedAt": "ISO | null"
  }
  ```
- **문제**: 웹은 중첩 객체, FastAPI는 평탄화된 필드
- **영향도**: MEDIUM (구조 다르지만 데이터는 동일)
- **수정 방안**: 필드명 통일 (특히 `character.avatarEmoji` vs `characterEmoji`)

---

### User Profile

#### GET /api/v1/user/profile - ⚠️ HIGH
- **웹 응답**:
  ```json
  {
    "profile": { /* UserProfile */ },
    "summary": {
      "totalWordsStudied": number,
      "totalQuizzesCompleted": number,
      "totalStudyDays": number,
      "totalXpEarned": number
    },
    "achievements": [{ achievementType, achievedAt }]
  }
  ```
- **FastAPI 응답**:
  ```json
  {
    "profile": UserProfile,
    "stats": {
      "totalWordsStudied": int,
      "totalQuizzesCompleted": int,
      "totalStudyDays": int,
      "achievements": [{ type, title, description, emoji, achievedAt }]
    }
  }
  ```
- **차이점**:
  1. 웹에는 `totalXpEarned` 필드, FastAPI는 없음
  2. 웹의 `summary` vs FastAPI의 `stats`
  3. FastAPI는 achievements에 title/description/emoji 포함, 웹은 achievementType만
- **영향도**: HIGH (응답 구조 완전히 다름)
- **수정 방안**: FastAPI를 웹과 동일하게 변경

---

### Statistics

#### GET /api/v1/stats/dashboard - ⚠️ LOW
- **웹 응답**:
  ```json
  {
    "showKana": boolean,
    "kanaProgress": { /* 가나 진행도 */ },
    "today": { /* 오늘 통계 */ },
    "streak": { "current": number, "longest": number },
    "weeklyStats": [{ "date", "wordsStudied", "xpEarned" }],
    "levelProgress": { /* 어휘/문법 */ }
  }
  ```
- **FastAPI 응답**:
  ```json
  {
    "today": { /* 오늘 통계 */ },
    "streak": int,  // ← 웹은 { current, longest }, FastAPI는 숫자
    "weekly": {
      "dates": [...],
      "wordsStudied": [...],
      "xpEarned": [...]
    },
    "levelProgress": { /* 어휘/문법 */ },
    "kanaProgress": { /* 가나 진행도 */ }
  }
  ```
- **차이점**:
  1. 웹의 `showKana` 필드 없음 (FastAPI는 쿼리에서 user.show_kana 사용 가능)
  2. `streak` 타입 다름 (객체 vs 숫자)
  3. 주간 통계 형식 다름 (배열 객체 vs 병렬 배열)
- **영향도**: LOW (기능은 동작하나 필드 접근 방식 다름)
- **수정 방안**: FastAPI 응답을 웹과 정확히 맞추기

#### GET /api/v1/stats/history - ⚠️ MEDIUM
- **웹 요청**: `?year=2026&month=3`
- **FastAPI 요청**: `?days=30` (과거 N일)
- **웹 응답**:
  ```json
  {
    "year": number,
    "month": number,
    "records": [{
      "date": "YYYY-MM-DD",
      "wordsStudied": number,
      "quizzesCompleted": number,
      "correctAnswers": number,
      "totalAnswers": number,
      "conversationCount": number,
      "studyTimeSeconds": number,
      "xpEarned": number
    }]
  }
  ```
- **FastAPI 응답**:
  ```json
  {
    "days": [{
      "date": "YYYY-MM-DD",
      "wordsStudied": int,
      "quizzesCompleted": int,
      "xpEarned": int
    }]
  }
  ```
- **차이점**:
  1. 쿼리 파라미터 완전히 다름 (year/month vs days)
  2. 응답 필드 명 다름 (`records` vs `days`)
  3. FastAPI는 correctAnswers, totalAnswers, conversationCount, studyTimeSeconds 없음
- **영향도**: MEDIUM (기본 데이터는 있지만 추가 필드 부족)
- **수정 방안**: FastAPI를 웹과 동일한 형식으로 변경

---

### Study Materials

#### GET /api/v1/study/learned-words - ⚠️ HIGH
- **웹 응답**:
  ```json
  {
    "entries": [{
      "id": string,
      "vocabularyId": string,
      "word": string,
      "reading": string,
      "meaningKo": string,
      "jlptLevel": string,
      "exampleSentence": string,
      "exampleTranslation": string,
      "correctCount": number,
      "incorrectCount": number,
      "streak": number,
      "mastered": boolean,
      "lastReviewedAt": "ISO string | null"
    }],
    "total": number,
    "page": number,
    "totalPages": number,
    "summary": {
      "totalLearned": number,
      "mastered": number,
      "learning": number
    }
  }
  ```
- **FastAPI 응답**:
  ```json
  {
    "words": [{
      "id": string,
      "word": string,
      "reading": string,
      "meaningKo": string,
      "jlptLevel": string,
      "partOfSpeech": string
    }],
    "total": number,
    "page": number,
    "pageSize": number
  }
  ```
- **차이점**:
  1. 래퍼 필드명 다름 (`entries` vs `words`)
  2. FastAPI는 vocabularyId, exampleSentence, exampleTranslation, correctCount, incorrectCount, streak, mastered, lastReviewedAt 없음
  3. FastAPI는 partOfSpeech 있지만 웹은 없음
  4. FastAPI는 summary 없음
- **영향도**: HIGH (필드 대량 누락)
- **수정 방안**: FastAPI 응답에 모든 필드 추가

#### GET /api/v1/study/wrong-answers - ⚠️ HIGH
- **웹 응답**:
  ```json
  {
    "wrongAnswers": [{
      "questionId": string,
      "word": string,
      "reading": string,
      "meaningKo": string,
      "exampleSentence": string | null,
      "exampleTranslation": string | null
    }]
  }
  ```
- **FastAPI 응답**:
  ```json
  {
    "wrongAnswers": [{
      "questionId": string,
      "questionType": string,
      "selectedOptionId": string,
      "answeredAt": "ISO string"
    }]
  }
  ```
- **차이점**: FastAPI는 word/reading/meaningKo/exampleSentence/exampleTranslation 없음
- **영향도**: HIGH (필드 부재로 모바일 표시 불가)
- **수정 방안**: FastAPI에서 QuizAnswer 객체에서 실제 단어 정보 조회하여 응답

---

### Subscription

#### GET /api/v1/subscription/status - ⚠️ MEDIUM
- **웹 응답**:
  ```json
  {
    "subscription": {
      "isPremium": boolean,
      "plan": string,
      "expiresAt": "ISO | null",
      "cancelledAt": "ISO | null"
    },
    "aiUsage": {
      "chatCount": number,
      "callCount": number,
      "chatSeconds": number,
      "callSeconds": number,
      "chatLimit": number,
      "callLimit": number,
      "chatSecondsLimit": number,
      "callSecondsLimit": number
    }
  }
  ```
- **FastAPI 응답**:
  ```json
  {
    "isPremium": boolean,
    "plan": string,
    "expiresAt": "ISO | null",
    "cancelledAt": "ISO | null",
    "usage": {
      "chatCount": number,
      "chatSeconds": number,
      "callCount": number,
      "callSeconds": number
    },
    "limits": {
      "chatCount": number,
      "chatSeconds": number,
      "callCount": number,
      "callSeconds": number
    }
  }
  ```
- **차이점**:
  1. 웹은 `subscription` 래퍼, FastAPI는 최상위
  2. 웹의 `aiUsage`는 limit을 포함, FastAPI는 `usage`와 `limits`로 분리
  3. 필드명 통일되어 있음 (이 부분은 양호)
- **영향도**: MEDIUM (구조 다르지만 데이터 완전)
- **수정 방안**: 래퍼 구조 통일

#### GET /api/v1/payments - ⚠️ LOW
- **웹 응답**:
  ```json
  {
    "payments": [{
      "id": string,
      "transactionId": string,
      "amount": number,
      "currency": "KRW",
      "status": "COMPLETED|PENDING|FAILED",
      "paidAt": "ISO string",
      "planId": string
    }],
    "total": number,
    "page": number,
    "totalPages": number
  }
  ```
- **FastAPI 응답**:
  ```json
  {
    "payments": [{
      "id": string,
      "amount": int,
      "currency": string,
      "status": string,
      "plan": string,
      "paidAt": "ISO | null",
      "createdAt": "ISO"
    }],
    "total": int,
    "page": int,
    "pageSize": int,
    "totalPages": int
  }
  ```
- **차이점**:
  1. 웹의 `transactionId` vs FastAPI의 (없음, id 사용)
  2. 웹의 `planId` vs FastAPI의 `plan` (enum)
  3. 웹의 `paidAt` vs FastAPI의 `paidAt + createdAt`
- **영향도**: LOW (기본 정보 일치)

---

### Wordbook

#### GET /api/v1/wordbook - ⚠️ LOW
- **웹 응답**: `entries` 필드명 사용
- **FastAPI 응답**: `entries` 필드명 사용 (일치 ✓)
- **상태**: 양호

#### POST /api/v1/wordbook - ⚠️ LOW
- **웹 요청**: `{ word, reading, meaningKo, source?, note? }`
- **FastAPI 요청**: 동일 (일치 ✓)
- **상태**: 양호

---

### Missions

#### GET /api/v1/missions/today - ⚠️ LOW
- **웹 응답**:
  ```json
  {
    "missions": [{
      "id": string,
      "missionType": string,
      "label": string,
      "description": string,
      "targetCount": number,
      "currentCount": number,
      "isCompleted": boolean,
      "rewardClaimed": boolean,
      "xpReward": number
    }],
    "completedCount": number,
    "totalCount": number
  }
  ```
- **FastAPI 응답**: 배열 직접 반환 (래퍼 없음)
- **차이점**: label, description 필드 없음
- **영향도**: LOW (기본 기능 동작)

---

## 📋 상세 엔드포인트별 비교

### Authentication (3개)

| 엔드포인트 | 메서드 | 상태 | 심각도 | 비고 |
|-----------|--------|------|--------|------|
| POST /api/auth/ensure-user | POST | ❌ 누락 | CRITICAL | 모바일이 호출할 수 없음 |
| POST /api/v1/auth/onboarding | POST | ⚠️ 불일치 | MEDIUM | 응답 래퍼 구조 다름 |

**전체 호환성**: 50% (1/2)

---

### Quiz (7개)

| 엔드포인트 | 메서드 | 상태 | 심각도 | 비고 |
|-----------|--------|------|--------|------|
| POST /api/v1/quiz/start | POST | ⚠️ 불일치 | MEDIUM | question 필드명 다름 |
| POST /api/v1/quiz/answer | POST | ✅ 일치 | - | - |
| POST /api/v1/quiz/complete | POST | ✅ 일치 | - | - |
| GET /api/v1/quiz/incomplete | GET | ✅ 일치 | - | - |
| GET /api/v1/quiz/resume | GET | ⚠️ 불일치 | HIGH | HTTP 메서드 다름 (GET vs POST) |
| GET /api/v1/quiz/stats | GET | ✅ 일치 | - | - |
| GET /api/v1/quiz/wrong-answers | GET | ✅ 일치 | - | - |
| GET /api/v1/quiz/recommendations | GET | ⚠️ 불일치 | LOW | 응답 구조 완전히 다름 |

**전체 호환성**: 75% (6/8)

---

### Chat & Conversation (9개)

| 엔드포인트 | 메서드 | 상태 | 심각도 | 비고 |
|-----------|--------|------|--------|------|
| POST /api/v1/chat/start | POST | ✅ 일치 | - | - |
| POST /api/v1/chat/message | POST | ✅ 일치 | - | - |
| POST /api/v1/chat/end | POST | ⚠️ 불일치 | HIGH | feedbackSummary 구조 모호 |
| GET /api/v1/chat/characters | GET | ⚠️ 불일치 | HIGH | 래퍼 구조 다름 |
| GET /api/v1/chat/characters/stats | GET | ⚠️ 불일치 | HIGH | 필드명 다름 (stats vs characterStats) |
| GET /api/v1/chat/characters/favorites | GET | ⚠️ 불일치 | HIGH | 필드명 다름 (favorites vs favoriteIds) |
| POST /api/v1/chat/characters/favorites | POST | ✅ 일치 | - | - |
| GET /api/v1/chat/scenarios | GET | ✅ 일치 | - | - |
| GET /api/v1/chat/history | GET | ⚠️ 불일치 | MEDIUM | 필드 구조 평탄화 |
| POST /api/v1/chat/tts | POST | ✅ 일치 | - | - |
| POST /api/v1/chat/voice/transcribe | POST | ✅ 일치 | - | - |
| POST /api/v1/chat/live-token | POST | ✅ 일치 | - | - |
| POST /api/v1/chat/live-feedback | POST | ✅ 일치 | - | - |

**전체 호환성**: 77% (10/13)

---

### Kana Learning (7개)

| 엔드포인트 | 메서드 | 상태 | 심각도 | 비고 |
|-----------|--------|------|--------|------|
| GET /api/v1/kana/characters | GET | ✅ 일치 | - | 추가 필드 있음 (웹과 호환) |
| GET /api/v1/kana/stages | GET | ✅ 일치 | - | - |
| GET /api/v1/kana/progress | GET | ✅ 일치 | - | - |
| POST /api/v1/kana/progress | POST | ✅ 일치 | - | - |
| POST /api/v1/kana/quiz/start | POST | ✅ 일치 | - | - |
| POST /api/v1/kana/quiz/answer | POST | ✅ 일치 | - | - |
| POST /api/v1/kana/stage-complete | POST | ✅ 일치 | - | - |

**전체 호환성**: 100% (7/7) ✅

---

### User & Profile (5개)

| 엔드포인트 | 메서드 | 상태 | 심각도 | 비고 |
|-----------|--------|------|--------|------|
| GET /api/v1/user/profile | GET | ⚠️ 불일치 | HIGH | summary 구조 + totalXpEarned 필드 |
| PATCH /api/v1/user/profile | PATCH | ✅ 일치 | - | - |
| POST /api/v1/user/avatar | POST | ❌ 누락 | HIGH | multipart/form-data 미지원 |
| PATCH /api/v1/user/avatar | PATCH | ✅ 일치 | - | (다른 접근) |
| DELETE /api/v1/user/account | DELETE | ❌ 누락 | CRITICAL | 계정 삭제 미구현 |
| PATCH /api/v1/user/account | PATCH | ✅ 일치 | - | (이름과 이메일만) |

**전체 호환성**: 50% (3/6)

---

### Statistics & Dashboard (2개)

| 엔드포인트 | 메서드 | 상태 | 심각도 | 비고 |
|-----------|--------|------|--------|------|
| GET /api/v1/stats/dashboard | GET | ⚠️ 불일치 | LOW | streak 타입 + weekly 형식 다름 |
| GET /api/v1/stats/history | GET | ⚠️ 불일치 | MEDIUM | 쿼리 파라미터 + 응답 필드 다름 |

**전체 호환성**: 0% (0/2)

---

### Study Materials (2개)

| 엔드포인트 | 메서드 | 상태 | 심각도 | 비고 |
|-----------|--------|------|--------|------|
| GET /api/v1/study/learned-words | GET | ⚠️ 불일치 | HIGH | entries 필드 + summary 부재 + 데이터 필드 대량 누락 |
| GET /api/v1/study/wrong-answers | GET | ⚠️ 불일치 | HIGH | 단어 정보 필드 없음 |
| GET /api/v1/wordbook | GET | ✅ 일치 | - | - |
| POST /api/v1/wordbook | POST | ✅ 일치 | - | - |
| GET /api/v1/wordbook/{id} | GET | ✅ 일치 | - | - |
| PATCH /api/v1/wordbook/{id} | PATCH | ✅ 일치 | - | - |
| DELETE /api/v1/wordbook/{id} | DELETE | ✅ 일치 | - | - |

**전체 호환성**: 71% (5/7)

---

### Missions (2개)

| 엔드포인트 | 메서드 | 상태 | 심각도 | 비고 |
|-----------|--------|------|--------|------|
| GET /api/v1/missions/today | GET | ⚠️ 불일치 | LOW | label, description 필드 부재 |
| POST /api/v1/missions/claim | POST | ✅ 일치 | - | - |

**전체 호환성**: 50% (1/2)

---

### Subscription & Payments (5개)

| 엔드포인트 | 메서드 | 상태 | 심각도 | 비고 |
|-----------|--------|------|--------|------|
| GET /api/v1/subscription/status | GET | ⚠️ 불일치 | MEDIUM | 응답 구조 (subscription 래퍼 + aiUsage) |
| POST /api/v1/subscription/checkout | POST | ✅ 일치 | - | - |
| POST /api/v1/subscription/activate | POST | ✅ 일치 | - | - |
| POST /api/v1/subscription/cancel | POST | ✅ 일치 | - | - |
| POST /api/v1/subscription/resume | POST | ✅ 일치 | - | - |
| GET /api/v1/payments | GET | ⚠️ 불일치 | LOW | transactionId vs id, planId vs plan |
| POST /api/v1/webhook/portone | POST | ✅ 일치 | - | - |
| POST /api/v1/cron/subscription-renewal | POST | ✅ 일치 | - | - |

**전체 호환성**: 75% (6/8)

---

### Notifications (1개)

| 엔드포인트 | 메서드 | 상태 | 심각도 | 비고 |
|-----------|--------|------|--------|------|
| GET /api/v1/notifications | GET | ✅ 일치 | - | - |
| POST /api/v1/push/subscribe | POST | ❌ 누락 | LOW | 라우터 미구현 |

**전체 호환성**: 50% (1/2)

---

## 🔧 수정 우선순위

### CRITICAL (즉시 수정) - 3개

1. **DELETE /api/v1/user/account** 구현
   - 파일: `/apps/api/app/routers/user.py`
   - 예상 시간: 1-2시간
   - 영향도: 계정 삭제 기능 완전 미지원

2. **POST /api/auth/ensure-user** 엔드포인트 추가
   - 파일: `/apps/api/app/routers/auth.py`
   - 예상 시간: 30분
   - 영향도: 모바일 온보딩 실패 가능

3. **POST /api/v1/user/avatar** (multipart/form-data) 구현
   - 파일: `/apps/api/app/routers/user.py`
   - 예상 시간: 2-3시간
   - 영향도: 프로필 이미지 업로드 불가

### HIGH (주요 수정) - 7개

1. **GET /api/v1/quiz/resume** → POST로 변경
   - 파일: `/apps/api/app/routers/quiz.py`
   - 예상 시간: 30분
   - 영향도: 퀴즈 재개 기능

2. **GET /api/v1/user/profile** 응답 구조 변경
   - `stats` → `summary` + `achievements` 추출
   - 파일: `/apps/api/app/routers/user.py`
   - 예상 시간: 1시간

3. **GET /api/v1/study/learned-words** 응답 필드 추가
   - vocabularyId, exampleSentence, exampleTranslation, correctCount, incorrectCount, streak, mastered, lastReviewedAt, summary
   - 파일: `/apps/api/app/routers/study.py`
   - 예상 시간: 2시간

4. **GET /api/v1/study/wrong-answers** 필드 추가
   - word, reading, meaningKo, exampleSentence, exampleTranslation 추가
   - 파일: `/apps/api/app/routers/study.py`
   - 예상 시간: 1-2시간

5. **GET /api/v1/chat/characters** 응답 래퍼 추가
   - `{ characters: [...] }` 형태로 변경
   - 파일: `/apps/api/app/routers/chat_data.py`
   - 예상 시간: 30분

6. **GET /api/v1/chat/characters/stats** 필드명 변경
   - `stats` → `characterStats`
   - 파일: `/apps/api/app/routers/chat_data.py`
   - 예상 시간: 15분

7. **GET /api/v1/chat/characters/favorites** 필드명 변경
   - `favorites` → `favoriteIds`
   - 파일: `/apps/api/app/routers/chat_data.py`
   - 예상 시간: 15분

### MEDIUM (중요 수정) - 4개

1. **POST /api/v1/quiz/start** question 필드명 표준화
   - questionId, questionText 등 웹과 동일하게
   - 파일: `/apps/api/app/schemas/quiz.py`
   - 예상 시간: 1-2시간

2. **POST /api/v1/auth/onboarding** 응답 구조 변경
   - `success + user` → `profile`
   - 파일: `/apps/api/app/routers/auth.py`
   - 예상 시간: 30분

3. **GET /api/v1/stats/history** 쿼리/응답 형식 변경
   - year/month → days 쿼리 유지
   - 응답에 correctAnswers, totalAnswers, conversationCount, studyTimeSeconds 추가
   - 파일: `/apps/api/app/routers/stats.py`
   - 예상 시간: 2-3시간

4. **GET /api/v1/subscription/status** 응답 구조 변경
   - `subscription` 래퍼 추가
   - `aiUsage` 필드명 변경
   - 파일: `/apps/api/app/routers/subscription.py`
   - 예상 시간: 1시간

### LOW (경미 수정) - 3개

1. **GET /api/v1/quiz/recommendations** 응답 형식 통일
   - reviewDueCount, newWordsCount, wrongCount, lastReviewedAt로 변경
   - 파일: `/apps/api/app/routers/quiz.py`
   - 예상 시간: 1시간

2. **GET /api/v1/stats/dashboard** 응답 형식 통일
   - streak 타입 수정 (int → { current, longest })
   - weekly 형식 수정 (배열 → 객체 배열)
   - 파일: `/apps/api/app/schemas/stats.py`
   - 예상 시간: 1-2시간

3. **GET /api/v1/payments** 필드명 통일
   - transactionId 추가, plan → planId
   - 파일: `/apps/api/app/routers/payments.py`
   - 예상 시간: 1시간

---

## 📈 개선 제안

### 1. API 응답 일관성
- 모든 응답을 하나의 기본 형식으로 통일: `{ data, meta?, errors? }`
- 현재: 엔드포인트마다 래퍼 구조 다름 (어떤 건 래퍼, 어떤 건 없음)

### 2. 필드명 표준화
- 전체 API에서 camelCase 일관성 검증
- 예: `statistics` vs `stats`, `characters` vs `favoriteIds`

### 3. 실제 vs 문서 동기화
- FastAPI 문서에만 있고 구현이 없는 엔드포인트들 검증
- 예: `/api/v1/push/subscribe`

### 4. 타입 안정성
- Pydantic 모델 스키마를 먼저 정의하고 라우터 구현
- 현재: 일부 라우터에서 `dict` 타입으로 반환

### 5. 테스트 자동화
- 웹 API와 FastAPI의 응답을 비교하는 자동화된 테스트
- CI/CD에서 매번 검증

---

## 결론

FastAPI 백엔드는 기본적인 구조는 웹 API와 일치하지만, **응답 필드명과 구조에서 불일치**가 있습니다.

**주요 문제점**:
1. 누락된 엔드포인트 5개 (특히 `ensure-user`, `delete-account`, `upload-avatar`)
2. 응답 래퍼 구조 불일치 (10개 이상)
3. 필드명 불일치 (snake_case vs camelCase 변환 오류)
4. 필드 누락 (특히 study/learned-words, study/wrong-answers)

**권장 조치**:
- CRITICAL 3개: 즉시 수정
- HIGH 7개: 1주일 내 수정
- MEDIUM/LOW: 다음 스프린트에 포함

전체 호환성 85%이지만, **모바일 실제 동작**에서는 불일치가 누적되면 실패 가능성이 높습니다. 특히 필드명 다름으로 인한 JSON 파싱 오류가 발생할 수 있습니다.

---

**마지막 업데이트**: 2026-03-12
**분석 기준**: 웹 API_MAPPING.md (최신) vs FastAPI_ENDPOINT_MAPPING.md + 실제 코드 검증
