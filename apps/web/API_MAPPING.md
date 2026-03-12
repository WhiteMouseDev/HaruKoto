# Web (Next.js) API Routes - 완벽 매핑

**작성일**: 2026-03-12
**용도**: FastAPI 백엔드 개발의 "정답 기준"

---

## 📋 목차

1. [Authentication](#authentication)
2. [Quiz & Learning](#quiz--learning)
3. [Chat & Conversation](#chat--conversation)
4. [Kana Learning](#kana-learning)
5. [User & Profile](#user--profile)
6. [Statistics & Dashboard](#statistics--dashboard)
7. [Missions](#missions)
8. [Study Materials](#study-materials)
9. [Subscription & Payments](#subscription--payments)
10. [Notifications](#notifications)
11. [Voice & TTS](#voice--tts)

---

## Authentication

### POST /api/auth/ensure-user
인증된 사용자의 DB 레코드 자동 생성

**Request**: None (Supabase auth로부터 자동)
**Response**:
```json
{
  "user": {
    "id": "string",
    "email": "string",
    "nickname": "string | null",
    "avatarUrl": "string | null",
    "jlptLevel": "N5|N4|N3|N2|N1",
    "goal": "JLPT_N5|...|HOBBY",
    "dailyGoal": number,
    "experiencePoints": number,
    "level": number,
    "streakCount": number,
    "longestStreak": number,
    "lastStudyDate": "date | null",
    "isPremium": boolean,
    "createdAt": "ISO string"
  }
}
```
**비고**: Supabase Auth 후 자동 호출, 클라이언트에서 명시적 호출 없음

### POST /api/auth/onboarding
온보딩 정보 저장

**Request**:
```json
{
  "nickname": "string",
  "jlptLevel": "N5|N4|N3|N2|N1",
  "goal": "JLPT_N5|...|HOBBY",
  "dailyGoal": number
}
```
**Response**:
```json
{
  "profile": { /* user object */ }
}
```
**비고**: 로그인 직후 온보딩 페이지에서 호출

---

## Quiz & Learning

### POST /api/v1/quiz/start
퀴즈 세션 시작 (문제 생성)

**Request**:
```json
{
  "quizType": "VOCABULARY|GRAMMAR",
  "jlptLevel": "N5|N4|N3|N2|N1",
  "count": number,                    // 기본값: QUIZ_CONFIG.DEFAULT_COUNT
  "mode": "normal|review|arrange|typing|cloze"
}
```
**Response**:
```json
{
  "sessionId": "string",
  "questions": [
    {
      "questionId": "string",
      "questionText": "string",
      "questionSubText": "string | null",
      "hint": "string | null",
      "options": [{ "id": "string", "text": "string" }],
      "correctOptionId": "string",
      // arrange 모드 전용:
      "koreanSentence": "string",
      "japaneseSentence": "string",
      "tokens": "string[]",
      "explanation": "string",
      "grammarPoint": "string",
      // cloze 모드 전용:
      "sentence": "string",
      "translation": "string"
    }
  ],
  "totalQuestions": number,
  "message": "string (선택적, 콘텐츠 없을 때)"
}
```
**비고**:
- 미완료 세션 자동 완료 처리
- 스페이스드 반복(review) 로직 포함
- Prisma 직접 호출

### POST /api/v1/quiz/answer
개별 문제 답변 저장

**Request**:
```json
{
  "sessionId": "string",
  "questionId": "string",
  "selectedOptionId": "string",
  "timeSpentSeconds": number,
  "questionType": "VOCABULARY|GRAMMAR|CLOZE|SENTENCE_ARRANGE"
}
```
**Response**:
```json
{
  "success": true
}
```
**비고**:
- 정오답 서버사이드 검증
- spaced repetition 진행도 업데이트
- SM2 알고리즘 적용

### POST /api/v1/quiz/complete
퀴즈 세션 완료 & 보상 처리

**Request**:
```json
{
  "sessionId": "string"
}
```
**Response**:
```json
{
  "sessionId": "string",
  "totalQuestions": number,
  "correctCount": number,
  "accuracy": number,            // 백분율 (0-100)
  "xpEarned": number,
  "currentXp": number,
  "xpForNext": number,
  "level": number,
  "events": [
    {
      "type": "ACHIEVEMENT_UNLOCKED|...",
      "title": "string",
      "body": "string",
      "emoji": "string"
    }
  ]
}
```
**비고**:
- 멱등성 보장 (이미 완료된 세션은 기존 결과 반환)
- 일일 진행도(DailyProgress) 업데이트
- 게임화 로직: 레벨 업, 연속 학습 추적, 업적 체크

### POST /api/v1/quiz/resume
미완료 퀴즈 재개

**Request**:
```json
{
  "sessionId": "string"
}
```
**Response**:
```json
{
  "sessionId": "string",
  "questions": [/* question array */],
  "answeredQuestionIds": ["string"],
  "totalQuestions": number,
  "correctCount": number,
  "quizType": "VOCABULARY|GRAMMAR|..."
}
```
**비고**: 클라이언트가 진행 상황 복구 가능

### GET /api/v1/quiz/stats
퀴즈 통계 조회 (레벨별)

**Request**:
```
?level=N5&type=VOCABULARY
```
**Response**:
```json
{
  "totalCount": number,
  "studiedCount": number,
  "progress": number              // 백분율 (0-100)
}
```
**비고**: 레벨별 학습 진행도 표시

### GET /api/v1/quiz/incomplete
미완료 퀴즈 확인

**Request**: None
**Response**:
```json
{
  "session": {
    "id": "string",
    "quizType": "VOCABULARY|GRAMMAR|...",
    "jlptLevel": "N5|...",
    "totalQuestions": number,
    "answeredCount": number,
    "correctCount": number,
    "startedAt": "ISO string"
  } | null
}
```
**비고**: 24시간 이내 미완료 세션만 반환

### GET /api/v1/quiz/recommendations
추천 퀴즈 정보 조회

**Request**: None
**Response**:
```json
{
  "reviewDueCount": number,        // 복습 예정 단어
  "newWordsCount": number,         // 새로운 단어
  "wrongCount": number,            // 오답 단어
  "lastReviewedAt": "ISO string | null"
}
```
**비고**: 대시보드 추천 섹션용

### GET /api/v1/quiz/wrong-answers
오답 복습 조회

**Request**:
```
?sessionId=string
```
**Response**:
```json
{
  "wrongAnswers": [
    {
      "questionId": "string",
      "word": "string",
      "reading": "string | null",
      "meaningKo": "string",
      "exampleSentence": "string | null",
      "exampleTranslation": "string | null"
    }
  ]
}
```
**비고**: VOCABULARY/GRAMMAR 타입 모두 지원

---

## Chat & Conversation

### POST /api/v1/chat/start
채팅 세션 시작 (AI 인사말 생성)

**Request**:
```json
{
  "scenarioId": "string"
}
```
**Response**:
```json
{
  "conversationId": "string",
  "firstMessage": {
    "messageJa": "string",
    "messageKo": "string",
    "hint": "string"
  }
}
```
**비고**:
- AI 사용량 체크 및 레이트 제한 적용
- Supabase Rate Limit 적용
- getAIProvider() (OpenAI/Gemini) 호출

### POST /api/v1/chat/message
채팅 메시지 전송 & AI 응답

**Request**:
```json
{
  "conversationId": "string",
  "message": "string (max 2000)"
}
```
**Response**:
```json
{
  "messageJa": "string",
  "messageKo": "string",
  "feedback": [
    {
      "type": "string",
      "original": "string",
      "correction": "string",
      "explanationKo": "string"
    }
  ],
  "hint": "string",
  "newVocabulary": [
    {
      "word": "string",
      "reading": "string",
      "meaningKo": "string"
    }
  ]
}
```
**비고**:
- 트랜잭션 처리로 동시성 안전
- AI 응답 자동 파싱 (JSON/마크다운 지원)

### POST /api/v1/chat/end
채팅 세션 종료 & 평가

**Request**:
```json
{
  "conversationId": "string"
}
```
**Response**:
```json
{
  "success": true,
  "feedbackSummary": {
    "overallScore": number,        // 0-100
    "fluency": number,
    "accuracy": number,
    "vocabularyDiversity": number,
    "naturalness": number,
    "strengths": ["string"],
    "improvements": ["string"],
    "recommendedExpressions": ["string"]
  },
  "xpEarned": number,
  "events": [
    {
      "type": "ACHIEVEMENT_UNLOCKED|...",
      "title": "string",
      "body": "string",
      "emoji": "string"
    }
  ]
}
```
**비고**:
- 게임화 로직 적용 (XP, 레벨, 연속 학습)
- AI 통화 시간 기록

### POST /api/v1/chat/live-feedback
음성 통화 피드백 (STT 전사)

**Request**:
```json
{
  "transcript": [
    {
      "role": "user|assistant",
      "text": "string"
    }
  ],
  "durationSeconds": number,
  "scenarioId": "string (선택적)",
  "characterId": "string (선택적)"
}
```
**Response**:
```json
{
  "conversationId": "string",
  "feedbackSummary": {
    "overallScore": number,
    "fluency": number,
    "accuracy": number,
    "vocabularyDiversity": number,
    "naturalness": number,
    "strengths": ["string"],
    "improvements": ["string"],
    "recommendedExpressions": [
      {
        "ja": "string",
        "ko": "string"
      }
    ],
    "corrections": [
      {
        "original": "string",
        "corrected": "string",
        "explanation": "string"
      }
    ],
    "translatedTranscript": [
      {
        "role": "user|assistant",
        "ja": "string",
        "ko": "string"
      }
    ]
  },
  "xpEarned": number,
  "events": [/* game events */]
}
```
**비고**:
- STT 입력 음성(한국어 인식)을 일본어로 복원
- 상세한 발음/문법/어휘 피드백

### GET /api/v1/chat/characters
캐릭터 목록 조회

**Request**:
```
?id=string (선택적 - 특정 캐릭터 상세 조회)
```
**Response (목록)**:
```json
{
  "characters": [
    {
      "id": "string",
      "name": "string",
      "nameJa": "string",
      "nameRomaji": "string",
      "gender": "string",
      "description": "string",
      "relationship": "string",
      "speechStyle": "string",
      "targetLevel": "N5|...",
      "tier": "FREE|PREMIUM|...",
      "unlockCondition": "string | null",
      "isDefault": boolean,
      "avatarEmoji": "string",
      "avatarUrl": "string",
      "gradient": "string",
      "order": number
    }
  ]
}
```
**Response (상세)**:
```json
{
  "character": {
    // 위의 필드 + 추가:
    "ageDescription": "string",
    "backgroundStory": "string",
    "personality": "string",
    "voiceName": "string",
    "voiceBackup": "string",
    "silenceMs": number
  }
}
```
**비고**: 캐시: 5분 (Cache-Control: private, max-age=300)

### GET /api/v1/chat/characters/favorites
즐겨찾기 캐릭터 조회

**Request**: None
**Response**:
```json
{
  "favoriteIds": ["string"]
}
```

### POST /api/v1/chat/characters/favorites
캐릭터 즐겨찾기 토글

**Request**:
```json
{
  "characterId": "string"
}
```
**Response**:
```json
{
  "favorited": boolean
}
```
**비고**: 이미 즐겨찾기됨 → 제거, 아님 → 추가

### GET /api/v1/chat/characters/stats
캐릭터별 대화 통계

**Request**: None
**Response**:
```json
{
  "characterStats": {
    "characterId": number,
    // ... (모든 캐릭터별 대화 횟수)
  }
}
```

### GET /api/v1/chat/scenarios
시나리오 목록 조회

**Request**:
```
?category=TRAVEL|DAILY|BUSINESS|FREE&difficulty=BEGINNER|INTERMEDIATE|ADVANCED
```
**Response**:
```json
{
  "scenarios": [
    {
      "id": "string",
      "title": "string",
      "titleJa": "string",
      "description": "string",
      "category": "TRAVEL|DAILY|BUSINESS|FREE",
      "difficulty": "BEGINNER|INTERMEDIATE|ADVANCED",
      "estimatedMinutes": number,
      "keyExpressions": ["string"],
      "situation": "string",
      "yourRole": "string",
      "aiRole": "string"
    }
  ]
}
```
**비고**: 캐시: 5분 (Cache-Control: private, max-age=300)

### GET /api/v1/chat/history
대화 이력 조회 (페이지네이션)

**Request**:
```
?cursor=string&limit=10 (max 30)
```
**Response**:
```json
{
  "history": [
    {
      "id": "string",
      "type": "TEXT|VOICE",
      "createdAt": "ISO string",
      "endedAt": "ISO string",
      "messageCount": number,
      "overallScore": number | null,
      "scenario": {
        "title": "string",
        "titleJa": "string",
        "category": "string",
        "difficulty": "string"
      } | null,
      "character": {
        "id": "string",
        "name": "string",
        "nameJa": "string",
        "avatarEmoji": "string",
        "avatarUrl": "string"
      } | null
    }
  ],
  "nextCursor": "string | null"
}
```
**비고**: 커서 기반 페이지네이션

---

## Kana Learning

### POST /api/v1/kana/quiz/start
가나 퀴즈 시작

**Request**:
```json
{
  "kanaType": "HIRAGANA|KATAKANA",
  "stageNumber": number (선택적),
  "quizMode": "recognition|sound_matching|kana_matching",
  "count": number                 // 기본값: 5
}
```
**Response**:
```json
{
  "sessionId": "string",
  "questions": [
    {
      "questionId": "string",
      "questionText": "string",
      "questionSubText": "string | null",
      "options": [{ "id": "string", "text": "string" }],
      "correctOptionId": "string"
    }
  ],
  "totalQuestions": number,
  "message": "string (선택적)"
}
```
**비고**:
- stageNumber 미제공 시 학습된 모든 문자 대상
- 이전 스테이지 누적 복습 포함

### POST /api/v1/kana/quiz/answer
가나 퀴즈 답변 (일반 퀴즈와 동일)

### POST /api/v1/kana/quiz/complete
가나 퀴즈 완료 (일반 퀴즈와 동일)

### GET /api/v1/kana/characters
가나 문자 목록 조회

**Request**:
```
?kanaType=HIRAGANA|KATAKANA&category=basic|combined
```
**Response**:
```json
{
  "characters": [
    {
      "id": "string",
      "character": "string",
      "romaji": "string",
      "pronunciation": "string",
      "kanaType": "HIRAGANA|KATAKANA",
      "category": "basic|combined",
      "order": number
    }
  ]
}
```

### GET /api/v1/kana/stages
가나 스테이지 조회

**Request**:
```
?kanaType=HIRAGANA|KATAKANA
```
**Response**:
```json
{
  "stages": [
    {
      "kanaType": "HIRAGANA|KATAKANA",
      "stageNumber": number,
      "characters": ["string"],
      "description": "string"
    }
  ]
}
```

### POST /api/v1/kana/stage-complete
스테이지 완료 표시

**Request**:
```json
{
  "kanaType": "HIRAGANA|KATAKANA",
  "stageNumber": number
}
```
**Response**:
```json
{
  "success": true
}
```

### GET /api/v1/kana/progress
가나 학습 진행도

**Request**: None
**Response**:
```json
{
  "hiragana": {
    "learned": number,
    "total": number,
    "pct": number
  },
  "katakana": {
    "learned": number,
    "total": number,
    "pct": number
  }
}
```

---

## User & Profile

### GET /api/v1/user/profile
사용자 프로필 조회

**Request**: None
**Response**:
```json
{
  "profile": {
    "id": "string",
    "email": "string",
    "nickname": "string",
    "avatarUrl": "string | null",
    "jlptLevel": "N5|N4|N3|N2|N1",
    "goal": "JLPT_N5|...|HOBBY",
    "dailyGoal": number,
    "experiencePoints": number,
    "level": number,
    "streakCount": number,
    "longestStreak": number,
    "lastStudyDate": "date | null",
    "isPremium": boolean,
    "callSettings": {
      "silenceDurationMs": number,
      "aiResponseSpeed": number,
      "subtitleEnabled": boolean,
      "autoAnalysis": boolean
    },
    "showKana": boolean,
    "createdAt": "ISO string",
    "levelProgress": {
      "currentXp": number,
      "xpForNext": number
    }
  },
  "summary": {
    "totalWordsStudied": number,
    "totalQuizzesCompleted": number,
    "totalStudyDays": number,
    "totalXpEarned": number
  },
  "achievements": [
    {
      "achievementType": "string",
      "achievedAt": "ISO string"
    }
  ]
}
```
**비고**: 캐시 없음 (Cache-Control: private, no-cache)

### PATCH /api/v1/user/profile
프로필 업데이트

**Request**:
```json
{
  "nickname": "string (선택적, max 20)",
  "jlptLevel": "N5|N4|N3|N2|N1 (선택적)",
  "dailyGoal": number (선택적, 1-100),
  "goal": "JLPT_N5|...|HOBBY (선택적)",
  "callSettings": {
    "silenceDurationMs": number (선택적, 0-5000),
    "aiResponseSpeed": number (선택적, 0.8-1.2),
    "subtitleEnabled": boolean (선택적),
    "autoAnalysis": boolean (선택적)
  },
  "showKana": boolean (선택적)
}
```
**Response**:
```json
{
  "profile": { /* updated user object */ }
}
```

### POST /api/v1/user/avatar
프로필 이미지 업로드

**Request**: multipart/form-data
```
file: File
```
**Response**:
```json
{
  "avatarUrl": "string"
}
```
**비고**: GCS에 업로드 (Google Cloud Storage)

### DELETE /api/v1/user/account
계정 완전 삭제

**Request**: None
**Response**:
```json
{
  "ok": true
}
```
**비고**:
- GCS의 아바타 파일 삭제 (비동기, 최선 노력)
- Prisma로 모든 관련 데이터 CASCADE 삭제
- Supabase Auth 유저 삭제

---

## Statistics & Dashboard

### GET /api/v1/stats/dashboard
대시보드 통계 조회

**Request**: None
**Response**:
```json
{
  "showKana": boolean,
  "kanaProgress": {
    "hiragana": {
      "learned": number,
      "total": number,
      "pct": number
    },
    "katakana": {
      "learned": number,
      "total": number,
      "pct": number
    }
  },
  "today": {
    "wordsStudied": number,
    "quizzesCompleted": number,
    "correctAnswers": number,
    "totalAnswers": number,
    "xpEarned": number,
    "goalProgress": number          // 0.0 ~ 1.0
  },
  "streak": {
    "current": number,
    "longest": number
  },
  "weeklyStats": [
    {
      "date": "YYYY-MM-DD",
      "wordsStudied": number,
      "xpEarned": number
    }
  ],
  "levelProgress": {
    "vocabulary": {
      "total": number,
      "mastered": number,
      "inProgress": number
    },
    "grammar": {
      "total": number,
      "mastered": number,
      "inProgress": number
    }
  }
}
```
**비고**: 캐시 없음 (Cache-Control: private, no-cache)

### GET /api/v1/stats/history
월별 학습 이력 조회

**Request**:
```
?year=2026&month=3
```
**Response**:
```json
{
  "year": number,
  "month": number,
  "records": [
    {
      "date": "YYYY-MM-DD",
      "wordsStudied": number,
      "quizzesCompleted": number,
      "correctAnswers": number,
      "totalAnswers": number,
      "conversationCount": number,
      "studyTimeSeconds": number,
      "xpEarned": number
    }
  ]
}
```
**비고**:
- 현재 달: 60초 캐시
- 과거 달: 24시간 캐시

---

## Missions

### GET /api/v1/missions/today
오늘의 미션 조회

**Request**: None
**Response**:
```json
{
  "missions": [
    {
      "id": "string",
      "missionType": "string",
      "label": "string",
      "description": "string",
      "targetCount": number,
      "currentCount": number,
      "isCompleted": boolean,
      "rewardClaimed": boolean,
      "xpReward": number
    }
  ],
  "completedCount": number,
  "totalCount": number
}
```
**비고**:
- 미션 없음 → 결정적 선택 (날짜 + userId 시드)
- 완료된 미션 자동 보상 지급

### POST /api/v1/missions/claim
미션 보상 수령

**Request**:
```json
{
  "missionId": "string"
}
```
**Response**:
```json
{
  "success": true,
  "xpEarned": number
}
```

---

## Study Materials

### GET /api/v1/study/learned-words
학습한 단어 목록 (페이지네이션)

**Request**:
```
?page=1&limit=10&sort=recent|alphabetical|most-studied&search=&filter=ALL|MASTERED|LEARNING
```
**Response**:
```json
{
  "entries": [
    {
      "id": "string",
      "vocabularyId": "string",
      "word": "string",
      "reading": "string",
      "meaningKo": "string",
      "jlptLevel": "N5|...",
      "exampleSentence": "string",
      "exampleTranslation": "string",
      "correctCount": number,
      "incorrectCount": number,
      "streak": number,
      "mastered": boolean,
      "lastReviewedAt": "ISO string | null"
    }
  ],
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

### GET /api/v1/study/wrong-answers
오답 복습 (study 탭)

**Request**:
```
?page=1&limit=10&sort=most-wrong|recent|alphabetical&level=N5|...
```
**Response**:
```json
{
  "entries": [
    {
      "id": "string",
      "vocabularyId": "string",
      "word": "string",
      "reading": "string",
      "meaningKo": "string",
      "jlptLevel": "string",
      "exampleSentence": "string",
      "exampleTranslation": "string",
      "correctCount": number,
      "incorrectCount": number,
      "mastered": boolean,
      "lastReviewedAt": "ISO string | null"
    }
  ],
  "total": number,
  "page": number,
  "totalPages": number,
  "summary": {
    "totalWrong": number,
    "mastered": number,
    "remaining": number
  }
}
```

### GET /api/v1/wordbook
단어장 조회

**Request**:
```
?page=1&limit=10&sort=recent|alphabetical&search=&source=QUIZ|CONVERSATION|MANUAL
```
**Response**:
```json
{
  "entries": [
    {
      "id": "string",
      "userId": "string",
      "word": "string",
      "reading": "string",
      "meaningKo": "string",
      "source": "QUIZ|CONVERSATION|MANUAL",
      "note": "string | null",
      "createdAt": "ISO string"
    }
  ],
  "total": number,
  "page": number,
  "totalPages": number
}
```

### POST /api/v1/wordbook
단어장 항목 추가/수정

**Request**:
```json
{
  "word": "string",
  "reading": "string",
  "meaningKo": "string",
  "source": "QUIZ|CONVERSATION|MANUAL (선택적)",
  "note": "string | null (선택적)"
}
```
**Response**:
```json
{
  "id": "string",
  "word": "string",
  "reading": "string",
  "meaningKo": "string",
  "source": "string",
  "note": "string | null",
  "createdAt": "ISO string"
}
```
**비고**: upsert (userId_word 복합 키)

### DELETE /api/v1/wordbook/[id]
단어장 항목 삭제

**Request**: None
**Response**:
```json
{
  "success": true
}
```

---

## Subscription & Payments

### GET /api/v1/subscription/status
구독 상태 및 AI 사용량 조회

**Request**: None
**Response**:
```json
{
  "subscription": {
    "isPremium": boolean,
    "plan": "FREE|BASIC|PREMIUM",
    "expiresAt": "ISO string | null",
    "cancelledAt": "ISO string | null"
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
**비고**: 프리미엄/무료 상태에 따라 제한값 변동

### POST /api/v1/subscription/checkout
결제 체크아웃 시작

**Request**:
```json
{
  "planId": "string"
}
```
**Response**:
```json
{
  "checkoutUrl": "string"  // 결제 페이지 리다이렉트
}
```
**비고**: Portone (PG) 연동

### POST /api/v1/subscription/activate
구독 활성화

**Request**:
```json
{
  "transactionId": "string"
}
```
**Response**:
```json
{
  "success": true,
  "expiresAt": "ISO string"
}
```

### POST /api/v1/subscription/cancel
구독 취소

**Request**: None
**Response**:
```json
{
  "success": true,
  "cancelledAt": "ISO string"
}
```

### POST /api/v1/subscription/resume
취소된 구독 재개

**Request**: None
**Response**:
```json
{
  "success": true,
  "expiresAt": "ISO string"
}
```

### GET /api/v1/payments
결제 내역 조회

**Request**:
```
?page=1
```
**Response**:
```json
{
  "payments": [
    {
      "id": "string",
      "transactionId": "string",
      "amount": number,
      "currency": "KRW",
      "status": "COMPLETED|PENDING|FAILED",
      "paidAt": "ISO string",
      "planId": "string"
    }
  ],
  "total": number,
  "page": number,
  "totalPages": number
}
```

### POST /api/v1/webhook/portone
Portone 웹훅 (결제 완료 통지)

**Request** (Portone → Server):
```json
{
  "transactionId": "string",
  "status": "COMPLETED|FAILED",
  "amount": number,
  "currency": "string",
  "pgProvider": "string",
  "timestamp": "ISO string"
}
```
**Response**:
```json
{
  "success": true
}
```
**비고**: 클라이언트 호출 없음 (서버-to-서버)

---

## Notifications

### GET /api/v1/notifications
알림 목록 조회

**Request**:
```
?limit=20&offset=0
```
**Response**:
```json
{
  "notifications": [
    {
      "id": "string",
      "type": "ACHIEVEMENT_UNLOCKED|LEVEL_UP|...",
      "title": "string",
      "body": "string",
      "emoji": "string",
      "isRead": boolean,
      "createdAt": "ISO string"
    }
  ],
  "total": number
}
```

### POST /api/v1/push/subscribe
푸시 알림 구독

**Request**:
```json
{
  "subscription": {
    "endpoint": "string",
    "keys": {
      "p256dh": "string",
      "auth": "string"
    }
  }
}
```
**Response**:
```json
{
  "success": true
}
```
**비고**: Web Push API (선택적)

---

## Voice & TTS

### POST /api/v1/chat/tts
텍스트 음성 변환

**Request**:
```json
{
  "text": "string",
  "voiceName": "string",
  "characterId": "string (선택적)"
}
```
**Response**:
```json
{
  "audioUrl": "string",  // mp3 파일 URL
  "duration": number     // 초 단위
}
```
**비고**:
- Google Cloud TTS 호출
- 음성명 = AICharacter.voiceName

### POST /api/v1/chat/voice/transcribe
음성 인식 (STT)

**Request**: multipart/form-data
```
audio: File (mp3/wav)
```
**Response**:
```json
{
  "text": "string",
  "language": "ja|ko",
  "confidence": number
}
```
**비고**: Google Cloud Speech-to-Text 호출

### POST /api/v1/vocab/tts
단어 음성 변환

**Request**:
```json
{
  "word": "string",
  "reading": "string"
}
```
**Response**:
```json
{
  "audioUrl": "string",
  "duration": number
}
```

---

## 🔑 Key Points

### Request/Response 패턴
- 모든 API는 `/api/v1/` prefix 사용
- JSON request/response (multipart/form-data 제외)
- 모든 에러: `{ "error": "string" }` + HTTP status code

### 인증
- Supabase Auth를 통한 JWT 토큰 (쿠키에 자동 포함)
- 모든 요청에서 `await supabase.auth.getUser()` 확인

### 데이터 출처
- **Supabase**: 인증, RLS 정책
- **Prisma**: 모든 데이터 CRUD
- **Supabase Rate Limit**: AI 관련 요청 (chat, call)
- **Google Cloud**: TTS, STT, GCS (파일 저장)
- **Portone**: 결제 PG

### 게임화 로직
- Quiz Complete, Chat End, Live Feedback에서 자동 처리
- XP 획득 → 레벨 업 → 업적 체크 → 알림 생성
- Spaced Repetition (SM2): Quiz Answer 시 자동 적용

### 캐싱 정책
- 캐릭터/시나리오: 5분 (max-age=300)
- 대시보드/프로필: no-cache
- 통계: 현재 달 60초, 과거 달 24시간

---

## 📝 추가 정보

**마지막 업데이트**: 2026-03-12
**소스**: `/apps/web/src/app/api/**/*.ts`
**상태**: 정상 작동 중 (운영 데이터)
