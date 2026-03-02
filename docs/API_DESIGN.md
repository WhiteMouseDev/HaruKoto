# 하루코토 (HaruKoto) - API 설계서

> Next.js App Router Route Handlers 기반
> 기본 경로: `/api/v1/`

---

## 1. 인증 (Auth)

> Supabase Auth를 직접 사용하므로 커스텀 API 최소화.
> 아래는 Supabase Auth Client SDK로 처리하고, 서버 사이드 검증은 middleware(proxy.ts)에서 수행.

| 기능 | 방식 | 비고 |
|------|------|------|
| 소셜 로그인 | `supabase.auth.signInWithOAuth()` | Google, Kakao, Apple |
| 이메일 회원가입 | `supabase.auth.signUp()` | 이메일 인증 포함 |
| 이메일 로그인 | `supabase.auth.signInWithPassword()` | |
| 로그아웃 | `supabase.auth.signOut()` | |
| 세션 확인 | `supabase.auth.getSession()` | |

### 커스텀 인증 관련 API

```
POST /api/v1/auth/onboarding
  설명: 온보딩 완료 후 사용자 프로필 초기 설정
  Body: {
    nickname: string,
    jlptLevel: "N5" | "N4" | "N3" | "N2" | "N1",
    goal: "jlpt_n5" | "jlpt_n4" | "jlpt_n3" | "travel" | "business"
  }
  Response: {
    user: UserProfile
  }
```

---

## 2. 사용자 (Users)

```
GET /api/v1/users/me
  설명: 현재 로그인한 사용자 프로필 조회
  Auth: Required
  Response: {
    id: string,
    nickname: string,
    email: string,
    avatarUrl: string | null,
    jlptLevel: string,
    goal: string,
    experiencePoints: number,
    level: number,
    streakCount: number,
    lastStudyDate: string | null,
    isPremium: boolean,
    subscriptionExpiresAt: string | null,
    createdAt: string
  }

PATCH /api/v1/users/me
  설명: 사용자 프로필 수정
  Auth: Required
  Body: {
    nickname?: string,
    avatarUrl?: string,
    jlptLevel?: string,
    goal?: string,
    dailyGoal?: number
  }
  Response: {
    user: UserProfile
  }

GET /api/v1/users/me/stats
  설명: 사용자 학습 통계 요약
  Auth: Required
  Response: {
    totalStudyTime: number,       // 분
    totalQuizCount: number,
    totalCorrectCount: number,
    streakCount: number,
    longestStreak: number,
    totalConversations: number,
    vocabularyMastered: number,
    grammarMastered: number
  }
```

---

## 3. JLPT 학습 콘텐츠 (Content)

### 3.1 단어 (Vocabulary)

```
GET /api/v1/vocabulary
  설명: 단어 목록 조회
  Auth: Required
  Query: {
    level: "N5" | "N4" | "N3" | "N2" | "N1",
    category?: string,           // "noun", "verb", "adjective" 등
    search?: string,             // 검색어
    page?: number,               // 기본값: 1
    limit?: number               // 기본값: 20, 최대: 100
  }
  Response: {
    data: Vocabulary[],
    pagination: {
      page: number,
      limit: number,
      total: number,
      totalPages: number
    }
  }

GET /api/v1/vocabulary/:id
  설명: 단어 상세 조회
  Auth: Required
  Response: {
    id: string,
    word: string,               // 일본어 (한자)
    reading: string,            // 히라가나
    meaningKo: string,          // 한국어 뜻
    partOfSpeech: string,
    jlptLevel: string,
    exampleSentence: string,
    exampleTranslation: string,
    tags: string[],
    audioUrl: string | null
  }
```

### 3.2 문법 (Grammar)

```
GET /api/v1/grammar
  설명: 문법 목록 조회
  Auth: Required
  Query: {
    level: "N5" | "N4" | "N3" | "N2" | "N1",
    page?: number,
    limit?: number
  }
  Response: {
    data: Grammar[],
    pagination: Pagination
  }

GET /api/v1/grammar/:id
  설명: 문법 상세 조회
  Auth: Required
  Response: {
    id: string,
    pattern: string,            // 문법 패턴 (예: "〜てください")
    meaningKo: string,
    explanation: string,
    jlptLevel: string,
    exampleSentences: {
      japanese: string,
      reading: string,
      korean: string
    }[],
    relatedGrammarIds: string[]
  }
```

---

## 4. 퀴즈 (Quiz)

### 4.1 퀴즈 생성/풀기

```
POST /api/v1/quiz/start
  설명: 새 퀴즈 세션 시작
  Auth: Required
  Body: {
    type: "vocabulary" | "grammar" | "kanji" | "listening",
    level: "N5" | "N4" | "N3" | "N2" | "N1",
    count: number,              // 문제 수 (기본: 20)
    mode: "new" | "review" | "mixed"  // 새 문제 / 복습 / 혼합
  }
  Response: {
    sessionId: string,
    questions: {
      id: string,
      questionText: string,     // 문제 텍스트
      questionSubText?: string, // 보조 텍스트 (읽기 등)
      options: {
        id: string,
        text: string
      }[],
      hint?: string
    }[],
    totalCount: number
  }

POST /api/v1/quiz/answer
  설명: 퀴즈 답안 제출 (문제별)
  Auth: Required
  Body: {
    sessionId: string,
    questionId: string,
    selectedOptionId: string,
    timeSpentSeconds: number
  }
  Response: {
    isCorrect: boolean,
    correctOptionId: string,
    explanation: string,
    vocabulary?: Vocabulary,     // 정답 단어 상세 정보
    grammar?: Grammar           // 정답 문법 상세 정보
  }

POST /api/v1/quiz/complete
  설명: 퀴즈 세션 완료
  Auth: Required
  Body: {
    sessionId: string
  }
  Response: {
    totalQuestions: number,
    correctCount: number,
    accuracy: number,           // 0~100
    totalTimeSeconds: number,
    experienceGained: number,
    streakBonus: number,
    incorrectItems: {
      questionId: string,
      word?: string,
      reading?: string,
      meaningKo?: string,
      correctAnswer: string,
      userAnswer: string
    }[],
    newLevel?: number           // 레벨업 시
  }
```

### 4.2 오답 노트

```
GET /api/v1/quiz/incorrect
  설명: 오답 목록 조회
  Auth: Required
  Query: {
    type?: "vocabulary" | "grammar" | "kanji",
    level?: string,
    page?: number,
    limit?: number
  }
  Response: {
    data: {
      id: string,
      type: string,
      vocabularyId?: string,
      grammarId?: string,
      word: string,
      reading: string,
      meaningKo: string,
      incorrectCount: number,
      lastIncorrectAt: string
    }[],
    pagination: Pagination
  }

DELETE /api/v1/quiz/incorrect/:id
  설명: 오답 노트에서 삭제 (마스터 표시)
  Auth: Required
  Response: { success: true }
```

---

## 5. 게이미피케이션 (Gamification)

```
GET /api/v1/gamification/streak
  설명: 연속 학습 정보 조회
  Auth: Required
  Response: {
    currentStreak: number,
    longestStreak: number,
    weeklyStatus: {
      day: string,              // "mon", "tue", ...
      studied: boolean
    }[],
    lastStudyDate: string | null
  }

GET /api/v1/gamification/daily-progress
  설명: 오늘의 학습 진행 상황
  Auth: Required
  Response: {
    dailyGoal: number,
    completedCount: number,
    progressPercent: number,
    experienceToday: number,
    quizResults: {
      type: string,
      count: number,
      correct: number
    }[]
  }

GET /api/v1/gamification/level
  설명: 레벨/경험치 정보
  Auth: Required
  Response: {
    currentLevel: number,
    currentXP: number,
    requiredXP: number,         // 다음 레벨까지
    progressPercent: number,
    title: string               // "초급 학습자", "중급 탐험가" 등
  }
```

---

## 6. AI 회화 (Conversation) - 프리미엄

### 6.1 시나리오

```
GET /api/v1/conversation/scenarios
  설명: 시나리오 카테고리 목록
  Auth: Required (Premium)
  Response: {
    categories: {
      id: string,
      name: string,             // "여행", "일상", "비즈니스"
      icon: string,
      scenarioCount: number,
      scenarios: {
        id: string,
        title: string,
        titleJa: string,
        description: string,
        difficulty: "beginner" | "intermediate" | "advanced",
        estimatedMinutes: number,
        keyExpressions: string[]
      }[]
    }[]
  }
```

### 6.2 AI 대화

```
POST /api/v1/conversation/start
  설명: 새 대화 세션 시작
  Auth: Required (Premium)
  Body: {
    scenarioId?: string,        // null이면 자유 대화
    difficulty: "beginner" | "intermediate" | "advanced",
    topic?: string              // 자유 대화 시 주제
  }
  Response: {
    conversationId: string,
    scenario?: {
      title: string,
      situation: string,        // 상황 설명
      yourRole: string,         // 사용자 역할
      aiRole: string            // AI 역할
    },
    initialMessage: {
      role: "assistant",
      contentJa: string,        // 일본어 메시지
      contentKo: string,        // 한국어 번역
    }
  }

POST /api/v1/conversation/message
  설명: 대화 메시지 전송 (스트리밍)
  Auth: Required (Premium)
  Body: {
    conversationId: string,
    content: string             // 사용자 입력 (일본어)
  }
  Response: (Server-Sent Events / 스트리밍)
  {
    role: "assistant",
    contentJa: string,
    contentKo: string,
    feedback?: {
      type: "grammar" | "expression" | "politeness",
      original: string,
      correction: string,
      explanation: string
    }[],
    hint?: string               // 다음 대화 힌트
  }

POST /api/v1/conversation/end
  설명: 대화 종료 + 피드백 리포트 생성
  Auth: Required (Premium)
  Body: {
    conversationId: string
  }
  Response: {
    report: {
      overallScore: number,     // 1~5
      fluency: number,          // 0~100
      accuracy: number,
      vocabularyDiversity: number,
      naturalness: number,
      goodExpressions: {
        expression: string,
        reason: string
      }[],
      improvements: {
        original: string,
        suggestion: string,
        explanation: string
      }[],
      newVocabulary: {
        word: string,
        reading: string,
        meaningKo: string
      }[]
    }
  }

GET /api/v1/conversation/history
  설명: 대화 기록 목록
  Auth: Required (Premium)
  Query: {
    page?: number,
    limit?: number
  }
  Response: {
    data: {
      id: string,
      scenarioTitle: string,
      scenarioCategory: string,
      createdAt: string,
      duration: number,         // 분
      overallScore: number
    }[],
    pagination: Pagination
  }

GET /api/v1/conversation/history/:id
  설명: 대화 기록 상세 (메시지 전체)
  Auth: Required (Premium)
  Response: {
    id: string,
    scenario: Scenario,
    messages: Message[],
    report: ConversationReport
  }
```

---

## 7. 학습 통계 (Statistics)

```
GET /api/v1/statistics/overview
  설명: 학습 통계 개요
  Auth: Required
  Query: {
    period: "week" | "month" | "year" | "all"
  }
  Response: {
    totalStudyTime: number,
    totalQuestions: number,
    averageAccuracy: number,
    categoryBreakdown: {
      vocabulary: { count: number, accuracy: number },
      grammar: { count: number, accuracy: number },
      kanji: { count: number, accuracy: number },
      conversation: { count: number, avgScore: number }
    }
  }

GET /api/v1/statistics/heatmap
  설명: GitHub 스타일 학습 히트맵
  Auth: Required
  Query: {
    year: number
  }
  Response: {
    data: {
      date: string,             // "2026-03-02"
      count: number,            // 학습량 (0~4 단계)
      studyTimeMinutes: number
    }[]
  }

GET /api/v1/statistics/weekly
  설명: 주간 학습 차트 데이터
  Auth: Required
  Query: {
    startDate: string,          // "2026-02-24"
    endDate: string
  }
  Response: {
    data: {
      date: string,
      studyTimeMinutes: number,
      quizCount: number,
      categories: {
        type: string,
        count: number
      }[]
    }[]
  }

GET /api/v1/statistics/jlpt-progress
  설명: JLPT 레벨별 학습 진도
  Auth: Required
  Response: {
    currentLevel: string,
    vocabulary: {
      total: number,
      mastered: number,
      learning: number,
      progressPercent: number
    },
    grammar: {
      total: number,
      mastered: number,
      learning: number,
      progressPercent: number
    },
    estimatedReadyDate: string | null  // 예상 합격 준비 완료일
  }
```

---

## 8. 단어장 (Word Book)

```
GET /api/v1/wordbook
  설명: 내 단어장 목록
  Auth: Required
  Query: {
    page?: number,
    limit?: number,
    sort?: "recent" | "alphabetical"
  }
  Response: {
    data: {
      id: string,
      word: string,
      reading: string,
      meaningKo: string,
      addedAt: string,
      source: "quiz" | "conversation" | "manual"
    }[],
    pagination: Pagination
  }

POST /api/v1/wordbook
  설명: 단어장에 단어 추가
  Auth: Required
  Body: {
    vocabularyId?: string,      // 기존 단어 ID
    word?: string,              // 직접 입력 시
    reading?: string,
    meaningKo?: string
  }
  Response: {
    id: string,
    word: string,
    reading: string,
    meaningKo: string
  }

DELETE /api/v1/wordbook/:id
  설명: 단어장에서 삭제
  Auth: Required
  Response: { success: true }
```

---

## 9. 구독 (Subscription)

```
GET /api/v1/subscription/status
  설명: 현재 구독 상태 조회
  Auth: Required
  Response: {
    isPremium: boolean,
    plan: "free" | "monthly" | "yearly" | null,
    expiresAt: string | null,
    trialEndsAt: string | null,
    cancelledAt: string | null
  }

POST /api/v1/subscription/checkout
  설명: 구독 결제 세션 생성
  Auth: Required
  Body: {
    plan: "monthly" | "yearly"
  }
  Response: {
    checkoutUrl: string         // Stripe/Toss 결제 페이지 URL
  }

POST /api/v1/subscription/webhook
  설명: 결제 웹훅 (Stripe/Toss)
  Auth: Webhook Secret
  Body: (결제 시스템별 상이)
  처리: 구독 상태 업데이트

POST /api/v1/subscription/cancel
  설명: 구독 취소
  Auth: Required
  Response: {
    cancelledAt: string,
    expiresAt: string           // 남은 기간까지는 사용 가능
  }
```

---

## 10. 공통 사항

### 10.1 인증 방식
- Supabase Auth JWT 토큰 (Authorization: Bearer 헤더)
- `proxy.ts`에서 토큰 검증 및 사용자 정보 주입
- 프리미엄 API는 추가로 구독 상태 검증

### 10.2 에러 응답 형식
```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "로그인이 필요합니다.",
    "statusCode": 401
  }
}
```

### 10.3 에러 코드
| 코드 | HTTP | 설명 |
|------|------|------|
| `UNAUTHORIZED` | 401 | 로그인 필요 |
| `FORBIDDEN` | 403 | 권한 없음 (프리미엄 필요 등) |
| `NOT_FOUND` | 404 | 리소스 없음 |
| `VALIDATION_ERROR` | 400 | 입력 검증 실패 |
| `RATE_LIMITED` | 429 | API 호출 제한 초과 |
| `INTERNAL_ERROR` | 500 | 서버 에러 |

### 10.4 Rate Limiting
| 사용자 유형 | 일반 API | AI 회화 API |
|------------|---------|------------|
| 무료 | 100회/분 | 차단 |
| 프리미엄 | 200회/분 | 30회/일 |

### 10.5 페이지네이션
```json
{
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "totalPages": 8
  }
}
```
