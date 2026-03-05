# 하루코토 (HaruKoto) - API 설계서

> Next.js App Router Route Handlers 기반
> 기본 경로: `/api/v1/`
> 인증: Supabase Auth JWT (Authorization: Bearer 헤더)

---

## 1. 인증 (Auth)

> Supabase Auth를 직접 사용하므로 커스텀 API 최소화.
> 소셜/이메일 로그인, 세션 확인은 Supabase Auth Client SDK로 처리하며,
> 서버 사이드 검증은 `proxy.ts`에서 수행.

| 기능            | 방식                                 | 비고                 |
| --------------- | ------------------------------------ | -------------------- |
| 소셜 로그인     | `supabase.auth.signInWithOAuth()`    | Google, Kakao, Apple |
| 이메일 회원가입 | `supabase.auth.signUp()`             | 이메일 인증 포함     |
| 이메일 로그인   | `supabase.auth.signInWithPassword()` |                      |
| 로그아웃        | `supabase.auth.signOut()`            |                      |
| 세션 확인       | `supabase.auth.getSession()`         |                      |

### 커스텀 인증 관련 API

```
POST /api/v1/auth/onboarding
  설명: 온보딩 완료 후 사용자 프로필 초기 설정 (Supabase user metadata + DB upsert)
  Auth: Y
  Body: {
    nickname: string,
    jlptLevel: "N5" | "N4" | "N3" | "N2" | "N1",
    goal: string
  }
  Response: {
    user: { id, email, nickname, jlptLevel, goal, onboardingCompleted }
  }
```

---

## 2. 사용자 (User)

```
GET /api/v1/user/profile
  설명: 현재 로그인한 사용자 프로필 + 학습 요약 + 업적 조회
  Auth: Y
  Response: {
    profile: {
      id, email, nickname, avatarUrl, jlptLevel, goal, dailyGoal,
      experiencePoints, level, streakCount, longestStreak,
      lastStudyDate, isPremium, callSettings, createdAt,
      levelProgress: { currentXp, xpForNext }
    },
    summary: {
      totalWordsStudied, totalQuizzesCompleted,
      totalStudyDays, totalXpEarned
    },
    achievements: { achievementType, achievedAt }[]
  }

PATCH /api/v1/user/profile
  설명: 사용자 프로필 수정 (제공된 필드만 업데이트)
  Auth: Y
  Body: {
    nickname?: string,             // 1~20자
    jlptLevel?: "N5" | "N4" | "N3" | "N2" | "N1",
    dailyGoal?: number,            // 1~100
    goal?: "JLPT_N5" | "JLPT_N4" | "JLPT_N3" | "JLPT_N2" | "JLPT_N1" | "TRAVEL" | "BUSINESS" | "HOBBY",
    callSettings?: {
      silenceDurationMs?: number,  // 0~5000
      aiResponseSpeed?: number,    // 0.8~1.2
      subtitleEnabled?: boolean,
      autoAnalysis?: boolean
    }
  }
  Response: { profile: UserProfile }

DELETE /api/v1/user/account
  설명: 계정 완전 삭제 (DB CASCADE + Supabase Auth 계정 삭제)
  Auth: Y
  Response: { ok: true }
```

---

## 3. 가나 학습 (Kana)

### 3.1 스테이지

```
GET /api/v1/kana/stages?type=HIRAGANA|KATAKANA
  설명: 가나 학습 스테이지 목록 + 사용자별 진행 상태 조회
  Auth: Y
  Query: { type: "HIRAGANA" | "KATAKANA" }
  Response: {
    stages: {
      id, stageNumber, name, characters: string[],
      isUnlocked, isCompleted, quizScore, order
    }[]
  }

GET /api/v1/kana/characters?type=HIRAGANA|KATAKANA&category?=string
  설명: 가나 문자 목록 + 사용자 학습 진행도 조회
  Auth: Y
  Query: {
    type: "HIRAGANA" | "KATAKANA",
    category?: string  // "basic", "dakuten" 등
  }
  Response: {
    characters: {
      id, kanaType, character, romaji, category, order,
      userProgress: { correctCount, incorrectCount, streak, mastered, lastReviewedAt } | null
    }[]
  }

GET /api/v1/kana/progress
  설명: 히라가나/가타카나 전체 학습 진행 요약
  Auth: Y
  Response: {
    hiragana: { total, learned, mastered },
    katakana: { total, learned, mastered }
  }

POST /api/v1/kana/stage-complete
  설명: 가나 스테이지 완료 처리 + XP 보상
  Auth: Y
  Body: {
    stageId: string,
    quizScore?: number
  }
  Response: {
    xpEarned: number,
    newLevel?: number,
    achievements?: string[]
  }
```

### 3.2 가나 퀴즈

```
POST /api/v1/kana/quiz/start
  설명: 가나 퀴즈 세션 시작
  Auth: Y
  Body: {
    kanaType: "HIRAGANA" | "KATAKANA",
    stageNumber?: number,          // 특정 스테이지 퀴즈 (없으면 전체)
    quizMode?: "recognition",      // 기본값: "recognition"
    count?: number                 // 문제 수, 기본값: 5
  }
  Response: {
    sessionId: string,
    questions: {
      id, questionText, options: { id, text }[]
    }[]
  }

POST /api/v1/kana/quiz/answer
  설명: 가나 퀴즈 답안 제출 (문제별)
  Auth: Y
  Body: {
    sessionId: string,
    questionId: string,
    selectedOptionId: string,
    timeSpentSeconds?: number
  }
  Response: {
    isCorrect: boolean,
    correctOptionId: string
  }

POST /api/v1/kana/quiz/complete
  설명: 가나 퀴즈 세션 완료 + XP 보상 + 업적 확인
  Auth: Y
  Body: { sessionId: string }
  Response: {
    correctCount: number,
    totalQuestions: number,
    accuracy: number,
    xpEarned: number,
    isPerfect: boolean,
    newLevel?: number,
    achievements?: string[]
  }
```

---

## 4. JLPT 퀴즈 (Quiz)

### 4.1 퀴즈 세션

```
POST /api/v1/quiz/start
  설명: JLPT 퀴즈 세션 시작 (미완료 세션 자동 마감 후 새 세션 생성)
  Auth: Y
  Body: {
    quizType: "VOCABULARY" | "GRAMMAR",
    jlptLevel: "N5" | "N4" | "N3" | "N2" | "N1",
    count?: number,   // 기본값: QUIZ_CONFIG.DEFAULT_COUNT
    mode?: "normal"   // 기본값: "normal"
  }
  Response: {
    sessionId: string,
    questions: {
      id, questionText, questionSubText?,
      options: { id, text }[],
      hint?
    }[],
    totalCount: number
  }

POST /api/v1/quiz/answer
  설명: 퀴즈 답안 제출 + SM-2 간격 반복 알고리즘으로 SRS 업데이트
  Auth: Y
  Body: {
    sessionId: string,
    questionId: string,
    selectedOptionId: string,
    timeSpentSeconds?: number,
    questionType?: "VOCABULARY" | "GRAMMAR"  // 기본값: "VOCABULARY"
  }
  Response: {
    isCorrect: boolean,
    correctOptionId: string
  }

POST /api/v1/quiz/complete
  설명: 퀴즈 세션 완료 + XP/스트릭 업데이트 + 업적 확인
  Auth: Y
  Body: { sessionId: string }
  Response: {
    correctCount: number,
    totalQuestions: number,
    accuracy: number,
    xpEarned: number,
    streakBonus?: number,
    newLevel?: number,
    achievements?: string[]
  }

POST /api/v1/quiz/resume
  설명: 미완료 세션 이어하기 (세션 데이터 + 남은 문제 반환)
  Auth: Y
  Body: { sessionId: string }
  Response: {
    session: { id, quizType, jlptLevel, totalQuestions, answers },
    remainingQuestions: Question[]
  }

GET /api/v1/quiz/incomplete
  설명: 24시간 이내 미완료 세션 조회
  Auth: Y
  Response: {
    session: {
      id, quizType, jlptLevel,
      totalQuestions, answeredCount, correctCount, startedAt
    } | null
  }
```

### 4.2 퀴즈 통계 및 오답

```
GET /api/v1/quiz/stats?level=N5&type=VOCABULARY
  설명: JLPT 레벨별 학습 진도 통계 (전체 수 / 학습 수 / 진행률)
  Auth: Y
  Query: {
    level?: string,                    // 기본값: "N5"
    type?: "VOCABULARY" | "GRAMMAR"    // 기본값: "VOCABULARY"
  }
  Response: {
    totalCount: number,
    studiedCount: number,
    progress: number   // 0~100
  }

GET /api/v1/quiz/wrong-answers?sessionId=string
  설명: 특정 퀴즈 세션의 오답 목록 조회
  Auth: Y
  Query: { sessionId: string }
  Response: {
    wrongAnswers: {
      questionId, questionType, selectedOptionId,
      correctOptionId, answeredAt
    }[]
  }
```

---

## 5. 학습 (Study)

```
GET /api/v1/study/learned-words
  설명: 학습한 단어 목록 조회 (필터/정렬/검색/페이지네이션 지원)
  Auth: Y
  Query: {
    page?: number,
    limit?: number,
    sort?: "recent" | "alphabetical",
    search?: string,
    filter?: "ALL" | "MASTERED" | "LEARNING"   // 기본값: "ALL"
  }
  Response: {
    data: UserVocabProgress[],
    pagination: { page, limit, total, totalPages }
  }

GET /api/v1/study/wrong-answers
  설명: 전체 오답 단어 목록 조회 (오답 노트)
  Auth: Y
  Query: {
    page?: number,
    limit?: number,
    sort?: "most-wrong" | "recent" | "alphabetical",
    level?: string   // JLPT 레벨 필터
  }
  Response: {
    data: {
      id, vocabularyId, word, reading, meaningKo, jlptLevel,
      incorrectCount, lastReviewedAt
    }[],
    pagination: { page, limit, total, totalPages }
  }
```

---

## 6. AI 회화 (Chat) - 제한적 무료 / 프리미엄 확장

### 6.1 시나리오 및 캐릭터

```
GET /api/v1/chat/scenarios
  설명: 회화 시나리오 목록 조회 (카테고리/난이도 필터 지원)
  Auth: Y
  Query: {
    category?: "TRAVEL" | "DAILY" | "BUSINESS" | "FREE",
    difficulty?: "BEGINNER" | "INTERMEDIATE" | "ADVANCED"
  }
  Response: {
    scenarios: {
      id, title, titleJa, category, difficulty,
      situation, yourRole, aiRole,
      keyExpressions: string[], isActive
    }[]
  }

GET /api/v1/chat/characters
  설명: AI 캐릭터 목록 조회 (id 파라미터 전달 시 단일 캐릭터 상세 조회)
  Auth: Y
  Query: { id?: string }
  Response (목록): {
    characters: {
      id, name, nameJa, nameRomaji, gender, ageDescription,
      description, relationship, tier, unlockCondition,
      isDefault, avatarEmoji, avatarUrl, gradient, order,
      targetLevel, speechStyle
    }[]
  }
  Response (단일): {
    character: { ...위 필드 + personality, voiceName, voiceBackup, silenceMs, backgroundStory }
  }

GET /api/v1/chat/characters/stats
  설명: 사용자별 캐릭터 대화 횟수 통계
  Auth: Y
  Response: {
    characterStats: Record<characterId, conversationCount>
  }

GET /api/v1/chat/characters/favorites
  설명: 즐겨찾기 캐릭터 ID 목록 조회
  Auth: Y
  Response: { favoriteIds: string[] }

POST /api/v1/chat/characters/favorites
  설명: 캐릭터 즐겨찾기 토글 (추가/제거)
  Auth: Y
  Body: { characterId: string }
  Response: { favoriteIds: string[] }
```

### 6.2 대화 세션

```
POST /api/v1/chat/start
  설명: 새 AI 대화 세션 시작 + AI 첫 메시지 생성
  Auth: Y (AI 사용량 제한 적용)
  Body: {
    scenarioId: string,
    characterId?: string
  }
  Response: {
    conversationId: string,
    scenario: { title, titleJa, situation, yourRole, aiRole, keyExpressions },
    initialMessage: { messageJa: string, messageKo: string, hint: string }
  }

POST /api/v1/chat/message
  설명: 대화 메시지 전송 + AI 응답 생성 (문법 피드백 포함)
  Auth: Y (Rate limited)
  Body: {
    conversationId: string,
    userMessage: string
  }
  Response: {
    messageJa: string,
    messageKo: string,
    feedback: {
      type: string,
      original: string,
      correction: string,
      explanationKo: string
    }[],
    hint: string,
    newVocabulary: { word, reading, meaningKo }[]
  }

POST /api/v1/chat/end
  설명: 대화 종료 + AI 피드백 요약 생성 + XP/스트릭/업적 업데이트
  Auth: Y (Rate limited)
  Body: { conversationId: string }
  Response: {
    feedbackSummary: object,
    xpEarned: number,
    newLevel?: number,
    achievements?: string[]
  }

POST /api/v1/chat/live-feedback
  설명: 대화 완료 후 상세 AI 피드백 리포트 생성 (점수, 교정, 추천 표현 등)
  Auth: Y
  Body: { conversationId: string }
  Response: {
    overallScore: number,         // 0~100
    fluency: number,
    accuracy: number,
    vocabularyDiversity: number,
    naturalness: number,
    strengths: string[],
    improvements: string[],
    recommendedExpressions: { ja: string, ko: string }[],
    corrections: {
      original: string,
      corrected: string,
      explanation: string
    }[],
    translatedTranscript: { role: "user" | "assistant", ja: string, ko: string }[]
  }

DELETE /api/v1/chat/:conversationId
  설명: 대화 기록 삭제 (본인 대화만 삭제 가능)
  Auth: Y
  Response: { success: true }

GET /api/v1/chat/history
  설명: 완료된 대화 기록 목록 조회 (커서 기반 페이지네이션)
  Auth: Y
  Query: {
    cursor?: string,   // 마지막 conversationId
    limit?: number     // 최대 30, 기본값: 10
  }
  Response: {
    conversations: {
      id, createdAt, endedAt, messageCount, feedbackSummary,
      scenario: { title, titleJa, category, difficulty },
      character: { id, name, nameJa, avatarEmoji }
    }[],
    nextCursor: string | null
  }
```

### 6.3 음성 (Voice / TTS / STT)

```
POST /api/v1/chat/tts
  설명: 일본어 텍스트를 음성으로 변환 (OpenAI TTS)
  Auth: Y (Rate limited)
  Body: {
    text: string,    // 1~4096자
    speed?: number   // 0.25~4.0, 기본값: 0.9
  }
  Response: audio/mpeg 바이너리 스트림

POST /api/v1/chat/voice/transcribe
  설명: 음성 파일을 텍스트로 변환 (OpenAI Whisper STT)
  Auth: Y (Rate limited)
  Body: FormData { audio: File }  // 최대 4.5MB
  지원 포맷: webm, mp3, mp4, wav, ogg, flac, m4a
  Response: { text: string }

POST /api/v1/chat/live-token
  설명: Gemini Live API용 임시 인증 토큰 발급 (유효시간 5분)
  Auth: Y (Rate limited)
  Response: {
    token: string,    // ephemeral access token
    wsUri: string     // WebSocket 엔드포인트 URI
  }
```

---

## 7. 미션 (Missions)

```
GET /api/v1/missions/today
  설명: 오늘의 일일 미션 3개 조회 (없으면 자동 생성, userId + 날짜 기반 결정론적 선택)
  Auth: Y
  Response: {
    missions: {
      id, missionType, label, description,
      targetCount, currentCount, isCompleted, rewardClaimed,
      xpReward
    }[]
  }

POST /api/v1/missions/claim
  설명: 완료된 미션의 XP 보상 수령
  Auth: Y
  Body: { missionId: string }  // UUID
  Response: {
    xpEarned: number,
    newLevel?: number
  }
```

---

## 8. 통계 (Stats)

```
GET /api/v1/stats/dashboard
  설명: 홈 대시보드용 통합 학습 통계 (오늘 진행, 주간 차트, 전체 진도)
  Auth: Y
  Response: {
    dailyGoal: number,
    streak: { current: number, longest: number },
    todayProgress: {
      wordsStudied, quizzesCompleted, correctAnswers,
      conversationCount, kanaLearned, xpEarned
    },
    weeklyStats: { date, wordsStudied, quizzesCompleted, xpEarned }[],
    vocabProgress: { mastered: number, learning: number },
    grammarProgress: { mastered: number, learning: number },
    kanaProgress: {
      hiragana: { learned, total },
      katakana: { learned, total }
    },
    totalVocab: number,
    totalGrammar: number
  }

GET /api/v1/stats/history?year=2026&month=3
  설명: 특정 월의 일별 학습 기록 (히트맵 데이터 등에 활용)
  Auth: Y
  Query: {
    year: number,   // 2020~2100
    month: number   // 1~12
  }
  Response: {
    records: {
      date, wordsStudied, quizzesCompleted, correctAnswers,
      conversationCount, kanaLearned, studyTimeSeconds, xpEarned
    }[]
  }
```

---

## 9. 단어장 (Wordbook)

```
GET /api/v1/wordbook
  설명: 내 단어장 목록 조회 (검색/필터/정렬/페이지네이션 지원)
  Auth: Y
  Query: {
    page?: number,
    limit?: number,
    sort?: "recent" | "alphabetical",
    search?: string,
    source?: "QUIZ" | "CONVERSATION" | "MANUAL"
  }
  Response: {
    entries: { id, word, reading, meaningKo, source, note, createdAt }[],
    total: number,
    page: number,
    totalPages: number
  }

POST /api/v1/wordbook
  설명: 단어장에 단어 추가 (같은 단어 존재 시 upsert)
  Auth: Y
  Body: {
    word: string,
    reading: string,
    meaningKo: string,
    source?: "QUIZ" | "CONVERSATION" | "MANUAL",  // 기본값: "MANUAL"
    note?: string
  }
  Response: WorkbookEntry (HTTP 201)

DELETE /api/v1/wordbook/:id
  설명: 단어장 항목 삭제 (본인 항목만 삭제 가능)
  Auth: Y
  Response: { message: "Entry deleted successfully" }
```

---

## 10. 알림 (Notifications)

```
GET /api/v1/notifications
  설명: 최근 알림 20개 + 읽지 않은 알림 수 조회
  Auth: Y
  Response: {
    notifications: { id, type, title, message, isRead, createdAt }[],
    unreadCount: number
  }

PATCH /api/v1/notifications
  설명: 알림 읽음 처리 (id 전달 시 개별 읽음, 미전달 시 전체 읽음)
  Auth: Y
  Body: { id?: string }  // UUID, 생략 시 전체 읽음
  Response: { success: true }
```

---

## 11. 푸시 알림 (Push)

```
POST /api/v1/push/subscribe
  설명: Web Push 구독 등록 또는 업데이트
  Auth: Y
  Body: {
    endpoint: string,
    keys: { p256dh: string, auth: string }
  }
  Response: { success: true }
```

---

## 12. 구독 (Subscription)

```
GET /api/v1/subscription/status
  설명: 현재 구독 상태 + AI 일일 사용량 조회
  Auth: Y
  Response: {
    subscription: {
      isPremium: boolean,
      plan: "FREE" | "MONTHLY" | "YEARLY" | null,
      expiresAt: string | null,
      cancelledAt: string | null
    },
    aiUsage: {
      chatCount, callCount, chatSeconds, callSeconds,
      chatLimit, callLimit, chatSecondsLimit, callSecondsLimit
    }
  }

POST /api/v1/subscription/checkout
  설명: 포트원 결제 주문 정보 생성 (클라이언트 결제창 초기화용)
  Auth: Y
  Body: { plan: "monthly" | "yearly" }
  Response: {
    paymentId: string,
    orderName: string,
    amount: number,
    storeId: string,
    channelKey: string,
    customer: { customerId, fullName, email }
  }

POST /api/v1/subscription/activate
  설명: 포트원 결제 완료 후 구독 활성화 (결제 금액 서버 사이드 검증)
  Auth: Y
  Body: {
    paymentId: string,
    plan: "monthly" | "yearly"
  }
  Response: {
    subscription: { isPremium, plan, expiresAt }
  }

POST /api/v1/subscription/cancel
  설명: 구독 취소 (남은 기간은 유지)
  Auth: Y
  Body: { reason?: string }
  Response: { success: true }

POST /api/v1/subscription/resume
  설명: 취소 예약된 구독 재개 (cancelledAt 초기화)
  Auth: Y
  Response: { success: true }
```

---

## 13. 결제 (Payments)

```
GET /api/v1/payments
  설명: 결제 내역 조회 (페이지네이션)
  Auth: Y
  Query: { page?: number }
  Response: {
    payments: { id, amount, plan, status, createdAt }[],
    pagination: { page, total, totalPages }
  }
```

---

## 14. 웹훅 (Webhook)

```
POST /api/v1/webhook/portone
  설명: 포트원 결제 웹훅 수신 처리 (HMAC 시그니처 검증 후 구독 활성화)
  Auth: x-portone-signature 헤더 (HMAC)
  이벤트 처리:
    - Transaction.Paid: 결제 완료 → 구독 활성화
  Response: { ok: true }
```

---

## 15. Cron 작업 (Cron)

```
GET /api/cron/daily-reminder
  설명: 매일 오전 9시 KST (0시 UTC) 실행. 오늘 미학습 사용자에게 푸시 알림 발송
  Auth: Authorization: Bearer {CRON_SECRET}
  Response: { sent: number, skipped: number }

POST /api/v1/cron/subscription-renewal
  설명: 만료된 활성 구독에 대해 빌링키 자동 결제 처리 (배치 최대 50건)
  Auth: Authorization: Bearer {CRON_SECRET}
  Response: {
    results: { id: string, success: boolean, error?: string }[]
  }
```

---

## 16. 공통 사항

### 16.1 인증 방식

- Supabase Auth JWT 토큰 (Authorization: Bearer 헤더)
- `proxy.ts`에서 토큰 검증 및 사용자 정보 주입
- AI 관련 API는 추가로 일일 사용량 제한(AI_LIMITS) 적용

### 16.2 에러 응답 형식

```json
{
  "error": "에러 메시지"
}
```

### 16.3 주요 HTTP 상태 코드

| 상태 코드 | 설명                                   |
| --------- | -------------------------------------- |
| 200       | 성공                                   |
| 201       | 생성 성공                              |
| 400       | 잘못된 요청 (유효성 검사 실패 등)      |
| 401       | 인증 필요 (미로그인 또는 토큰 만료)    |
| 403       | 권한 없음 (타인 리소스 접근 등)        |
| 404       | 리소스 없음                            |
| 429       | Rate Limit 초과 (Retry-After 헤더 포함)|
| 500       | 서버 내부 오류                         |
| 503       | 서비스 설정 미완료                     |

### 16.4 Rate Limiting

AI 관련 엔드포인트(chat/message, chat/start, chat/end, chat/tts, chat/voice/transcribe, chat/live-token)에는 인메모리 Rate Limiter가 적용됩니다.

| 사용자 유형 | AI Chat 횟수/일 | AI Call 횟수/일 |
| ----------- | --------------- | --------------- |
| 무료        | 제한 있음       | 제한 있음       |
| 프리미엄    | 확장 한도       | 확장 한도       |

> 구체적인 한도는 `AI_LIMITS` 상수 참고 (`subscription-constants.ts`)

### 16.5 페이지네이션

오프셋 기반 (기본):
```json
{
  "page": 1,
  "limit": 20,
  "total": 150,
  "totalPages": 8
}
```

커서 기반 (chat/history):
```json
{
  "nextCursor": "conversation-id-string"
}
```
