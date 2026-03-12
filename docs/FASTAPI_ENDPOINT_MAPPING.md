# FastAPI Backend - Complete Endpoint Mapping

## Overview
- **Base URL**: `/api/v1`
- **Authentication**: Most endpoints require `Depends(get_current_user)` (except health, public data, webhooks, cron)
- **Schema Conversion**: CamelModel base class converts snake_case → camelCase automatically

---

## 1. HEALTH CHECK

### GET /health
- **URL**: `/health`
- **Auth**: Not required
- **Request**: None
- **Response**: `{ status: "ok" }`
- **Service**: None

---

## 2. AUTH

### POST /api/v1/auth/onboarding
- **URL**: `/api/v1/auth/onboarding`
- **Auth**: Required (get_current_user)
- **Request**:
  - `nickname` (str)
  - `jlptLevel` (enum: N1-N5) → `jlpt_level`
  - `goal` (enum: JLPT_PREPARATION | CASUAL_LEARNING | BUSINESS | TRAVEL | optional)
  - `dailyGoal` (int, default: 10) → `daily_goal`
- **Response**:
  - `success` (bool)
  - `user` (UserProfile object with camelCase)
- **Service**: User model update
- **Note**: Sets `onboarding_completed = True`

---

## 3. USER

### GET /api/v1/user/profile
- **URL**: `/api/v1/user/profile`
- **Auth**: Required
- **Request**: None (query/path params: none)
- **Response**:
  ```
  {
    profile: UserProfile (camelCase),
    stats: {
      totalWordsStudied: int,
      totalQuizzesCompleted: int,
      totalStudyDays: int,
      achievements: [{ type, title, description, emoji, achievedAt }, ...]
    }
  }
  ```
- **Service**: Query UserVocabProgress, QuizSession, DailyProgress, UserAchievement counts

### PATCH /api/v1/user/profile
- **URL**: `/api/v1/user/profile`
- **Auth**: Required
- **Request** (UserProfileUpdate, camelCase input):
  - `nickname` (str, optional)
  - `jlptLevel` (JlptLevel, optional)
  - `dailyGoal` (int, optional)
  - `goal` (UserGoal, optional)
  - `showKana` (bool, optional)
  - `callSettings` (dict, optional) → merged with existing
- **Response**: UserProfile (camelCase)
- **Service**: User model update
- **Note**: call_settings merges, not overwrites

### PATCH /api/v1/user/avatar
- **URL**: `/api/v1/user/avatar`
- **Auth**: Required
- **Request**:
  - `avatarUrl` (str) → `avatar_url`
- **Response**: `{ avatarUrl: str }`
- **Service**: User model update

### PATCH /api/v1/user/account
- **URL**: `/api/v1/user/account`
- **Auth**: Required
- **Request** (camelCase input):
  - `nickname` (str, optional)
  - `email` (str, optional)
- **Response**: `{ nickname?: str, email?: str }` (only fields that were updated)
- **Service**: User model update

---

## 4. QUIZ

### POST /api/v1/quiz/start
- **URL**: `/api/v1/quiz/start`
- **Auth**: Required
- **Request** (QuizStartRequest):
  - `quizType` (enum: VOCABULARY | KANJI | LISTENING | GRAMMAR) → `quiz_type`
  - `jlptLevel` (JlptLevel) → `jlpt_level`
  - `count` (int, default: 10)
  - `mode` (str, default: "normal", options: "normal" | "review" | "cloze" | "arrange")
- **Response** (QuizStartResponse):
  - `sessionId` (UUID) → `session_id`
  - `questions` (list of QuizQuestion with camelCase):
    - `id` (UUID)
    - `type` (QuizType)
    - `question` (str)
    - `options` (list of { id: str, text: str })
    - `correctOptionId` (optional, for client-side validation)
  - `totalQuestions` (int)
- **Service**: Generates questions based on mode, creates QuizSession
- **Note**: Auto-completes incomplete sessions, uses SRS for review items

### POST /api/v1/quiz/answer
- **URL**: `/api/v1/quiz/answer`
- **Auth**: Required
- **Request** (QuizAnswerRequest):
  - `sessionId` (UUID)
  - `questionId` (UUID)
  - `selectedOptionId` (str)
  - `timeSpentSeconds` (int, default: 0)
  - `questionType` (QuizType)
- **Response**: `{ success: bool }`
- **Service**: Updates SRS progress (UserVocabProgress or UserGrammarProgress)
- **Note**: Validates answer against stored correctOptionId, updates interval/ease_factor

### POST /api/v1/quiz/complete
- **URL**: `/api/v1/quiz/complete`
- **Auth**: Required
- **Request** (QuizCompleteRequest):
  - `sessionId` (UUID)
- **Response** (QuizCompleteResponse):
  - `sessionId` (UUID)
  - `correctCount` (int)
  - `totalQuestions` (int)
  - `accuracy` (float, percent)
  - `xpEarned` (int)
  - `level` (int)
  - `currentXp` (int)
  - `xpForNext` (int)
  - `events` (list of achievement events)
- **Service**: Awards XP, updates streak, checks achievements
- **Note**: Idempotent (returns same response if already completed)

### GET /api/v1/quiz/incomplete
- **URL**: `/api/v1/quiz/incomplete`
- **Auth**: Required
- **Request**: None
- **Response**:
  ```
  {
    session: {
      id: str,
      quizType: str (camelCase),
      jlptLevel: str,
      totalQuestions: int,
      answeredCount: int,
      correctCount: int,
      startedAt: ISO string
    } | null
  }
  ```
- **Service**: Query most recent uncompleted QuizSession

### GET /api/v1/quiz/resume
- **URL**: `/api/v1/quiz/resume`
- **Auth**: Required
- **Request**: None
- **Response**:
  ```
  {
    session: {
      sessionId: str,
      questions: [{ id, type, question, options }],
      totalQuestions: int,
      correctCount: int,
      answeredIds: [str, ...]
    } | null
  }
  ```
- **Service**: Returns uncompleted session with questions (stripped of correctOptionId)

### GET /api/v1/quiz/stats
- **URL**: `/api/v1/quiz/stats?level=N1&type=VOCABULARY` (optional)
- **Auth**: Required
- **Request** (Query params):
  - `level` (str, optional) → JLPT level
  - `type` (str alias for query_type, optional) → Quiz type
- **Response**:
  - If level + type provided:
    ```
    {
      totalCount: int,
      studiedCount: int,
      progress: int (percent)
    }
    ```
  - Default:
    ```
    {
      totalQuizzes: int,
      totalCorrect: int,
      totalQuestions: int,
      accuracy: float (percent)
    }
    ```
- **Service**: Counts from Vocabulary/Grammar or QuizSession

### GET /api/v1/quiz/wrong-answers?session_id=<uuid>
- **URL**: `/api/v1/quiz/wrong-answers`
- **Auth**: Required
- **Request** (Query):
  - `session_id` (str)
- **Response**:
  ```
  {
    wrongAnswers: [{
      questionId: str,
      word: str | null,
      reading: str | null,
      meaningKo: str | null,
      pattern: str | null,
      selectedOption: str,
      correctOption: str
    }, ...]
  }
  ```
- **Service**: Query QuizAnswer where is_correct = False

### GET /api/v1/quiz/recommendations
- **URL**: `/api/v1/quiz/recommendations`
- **Auth**: Required
- **Request**: None
- **Response**:
  ```
  {
    recommendations: [{
      type: "review" | "normal",
      quizType: str,
      count: int,
      reason: str
    }, ...]
  }
  ```
- **Service**: Counts due review items and suggests quiz topics

---

## 5. KANA

### GET /api/v1/kana/characters
- **URL**: `/api/v1/kana/characters`
- **Auth**: Not required
- **Request** (Query):
  - `kana_type` (KanaType, optional) → KanaType enum
- **Response**:
  ```
  [{
    id: str,
    kanaType: str,
    character: str,
    romaji: str,
    pronunciation: str,
    row: int,
    column: int,
    strokeCount: int,
    strokeOrder: [str],
    audioUrl: str | null,
    exampleWord: str,
    exampleReading: str,
    exampleMeaning: str,
    category: str,
    order: int
  }, ...]
  ```
- **Service**: Query KanaCharacter

### GET /api/v1/kana/stages
- **URL**: `/api/v1/kana/stages`
- **Auth**: Required
- **Request** (Query):
  - `kana_type` (KanaType, optional)
- **Response**:
  ```
  [{
    id: str,
    kanaType: str,
    stageNumber: int,
    title: str,
    description: str,
    characters: [str],
    isUnlocked: bool,
    isCompleted: bool,
    quizScore: int | null
  }, ...]
  ```
- **Service**: Query KanaLearningStage, UserKanaStage

### GET /api/v1/kana/progress
- **URL**: `/api/v1/kana/progress`
- **Auth**: Required
- **Request**: None
- **Response** (KanaProgressResponse):
  ```
  {
    hiragana: { learned: int, mastered: int, total: int },
    katakana: { learned: int, mastered: int, total: int }
  }
  ```
- **Service**: Counts UserKanaProgress by type and mastered status

### POST /api/v1/kana/progress
- **URL**: `/api/v1/kana/progress`
- **Auth**: Required
- **Request**:
  - `kanaId` (str) → kana_id
- **Response**: `{ success: bool }`
- **Service**: Inserts or increments UserKanaProgress
- **Note**: Also updates DailyProgress.kana_learned

### POST /api/v1/kana/quiz/start
- **URL**: `/api/v1/kana/quiz/start`
- **Auth**: Required
- **Request** (KanaQuizStartRequest):
  - `kanaType` (KanaType)
  - `stageNumber` (int)
  - `quizMode` (str, default: "recognition", options: "recognition" | "sound_matching" | "kana_matching")
  - `count` (int, default: 10)
- **Response** (KanaQuizStartResponse):
  - `sessionId` (UUID)
  - `questions` (list of { id, question, options })
  - `totalQuestions` (int)
- **Service**: Creates QuizSession with KANA type

### POST /api/v1/kana/quiz/answer
- **URL**: `/api/v1/kana/quiz/answer`
- **Auth**: Required
- **Request** (KanaQuizAnswerRequest):
  - `sessionId` (UUID)
  - `questionId` (UUID)
  - `selectedOptionId` (str)
- **Response** (KanaQuizAnswerResponse):
  - `isCorrect` (bool)
  - `correctOptionId` (str)
- **Service**: Updates UserKanaProgress with streak/mastery logic

### POST /api/v1/kana/stage-complete
- **URL**: `/api/v1/kana/stage-complete`
- **Auth**: Required
- **Request** (KanaStageCompleteRequest):
  - `kanaType` (KanaType)
  - `stageNumber` (int)
  - `score` (int)
- **Response** (KanaStageCompleteResponse):
  - `success` (bool)
  - `xpEarned` (int)
  - `level` (int)
  - `currentXp` (int)
  - `xpForNext` (int)
  - `events` (list)
  - `nextStageUnlocked` (bool)
- **Service**: Awards XP, unlocks next stage, checks kana completion achievements
- **Note**: Auto-disables showKana when both hiragana and katakana complete

---

## 6. CHAT (AI Conversation)

### POST /api/v1/chat/start
- **URL**: `/api/v1/chat/start`
- **Auth**: Required
- **Request** (ChatStartRequest):
  - `scenarioId` (UUID | null)
  - `characterId` (UUID | null)
  - `type` (ConversationType, default: TEXT) → enum: TEXT | VOICE
- **Response** (ChatStartResponse):
  - `conversationId` (UUID)
  - `firstMessage` (ChatMessage):
    - `messageJa` (str)
    - `messageKo` (str)
    - `hint` (str | null)
- **Service**: Calls generate_chat_response, creates Conversation
- **Note**: Rate-limited (check_ai_limit), initial AI greeting message

### POST /api/v1/chat/message
- **URL**: `/api/v1/chat/message`
- **Auth**: Required
- **Request** (ChatMessageRequest):
  - `conversationId` (UUID)
  - `message` (str) (Korean user input)
- **Response** (ChatMessageResponse):
  - `messageJa` (str) (Japanese response)
  - `messageKo` (str) (Korean translation)
  - `feedback` (list of feedback items, optional)
  - `hint` (str | null)
  - `newVocabulary` (list of vocab objects, optional)
- **Service**: Calls generate_chat_response with history
- **Note**: Appends user + AI messages to conversation.messages

### POST /api/v1/chat/end
- **URL**: `/api/v1/chat/end`
- **Auth**: Required
- **Request** (ChatEndRequest):
  - `conversationId` (UUID)
- **Response** (ChatEndResponse):
  - `success` (bool)
  - `feedbackSummary` (dict | null)
  - `xpEarned` (int)
  - `events` (list of achievement events)
- **Service**: Generates feedback, awards XP, updates streak, tracks AI usage, checks achievements
- **Note**: Idempotent (already ended returns previous result)

### POST /api/v1/chat/tts
- **URL**: `/api/v1/chat/tts`
- **Auth**: Required
- **Request** (ChatTTSRequest):
  - `text` (str)
  - `voiceName` (str | null, optional)
- **Response**: Audio WAV binary (media_type: "audio/wav")
- **Service**: Calls generate_tts
- **Note**: Rate-limited

### POST /api/v1/chat/voice/transcribe
- **URL**: `/api/v1/chat/voice/transcribe`
- **Auth**: Required
- **Request**: File upload (multipart/form-data)
  - `file` (UploadFile, allowed: webm, mp3, mpeg, wav, ogg, flac, m4a, max 4.5MB)
- **Response**: `{ transcription: str }`
- **Service**: Calls transcribe_audio

### POST /api/v1/chat/live-token
- **URL**: `/api/v1/chat/live-token`
- **Auth**: Required
- **Request** (LiveTokenRequest):
  - `characterId` (UUID | null, optional)
- **Response**: Token data (for real-time voice conversation)
- **Service**: Calls generate_live_token
- **Note**: Rate-limited (LIVE_TOKEN limits), check_ai_limit for "call"

### POST /api/v1/chat/live-feedback
- **URL**: `/api/v1/chat/live-feedback`
- **Auth**: Required
- **Request** (LiveFeedbackRequest):
  - `conversationId` (UUID)
  - `duration` (int) (seconds)
- **Response**:
  ```
  {
    success: bool,
    conversationId: str,
    feedbackSummary: dict | null,
    xpEarned: int,
    events: list
  }
  ```
- **Service**: Generates live_feedback, awards XP, tracks usage
- **Note**: Similar to /end but for voice calls

---

## 7. CHAT DATA (Public/Shared Resources)

### GET /api/v1/chat/scenarios
- **URL**: `/api/v1/chat/scenarios`
- **Auth**: Not required
- **Request**: None
- **Response**:
  ```
  [{
    id: str,
    title: str,
    titleJa: str,
    description: str,
    category: str (enum),
    difficulty: str (enum),
    estimatedMinutes: int,
    keyExpressions: [str],
    situation: str,
    yourRole: str,
    aiRole: str,
    order: int
  }, ...]
  ```
- **Service**: Query ConversationScenario (where is_active = True)

### GET /api/v1/chat/history
- **URL**: `/api/v1/chat/history?cursor=<ISO_string>&limit=20`
- **Auth**: Required
- **Request** (Query):
  - `cursor` (str | null, ISO datetime for pagination)
  - `limit` (int, default: 20, max: 30)
- **Response**:
  ```
  {
    history: [{
      id: str,
      scenarioTitle: str | null,
      category: str | null,
      difficulty: str | null,
      characterName: str | null,
      characterEmoji: str | null,
      messageCount: int,
      overallScore: float | null,
      createdAt: ISO,
      endedAt: ISO | null
    }, ...],
    nextCursor: str | null
  }
  ```
- **Service**: Query Conversation with pagination

### GET /api/v1/chat/characters
- **URL**: `/api/v1/chat/characters`
- **Auth**: Required
- **Request**: None
- **Response**:
  ```
  [{
    id: str,
    name: str,
    nameJa: str,
    nameRomaji: str,
    gender: str,
    ageDescription: str,
    description: str,
    relationship: str,
    speechStyle: str,
    targetLevel: str,
    tier: str,
    unlockCondition: str,
    isDefault: bool,
    avatarEmoji: str,
    avatarUrl: str,
    gradient: str,
    order: int,
    isUnlocked: bool
  }, ...]
  ```
- **Service**: Query AiCharacter, UserCharacterUnlock

### GET /api/v1/chat/characters/stats
- **URL**: `/api/v1/chat/characters/stats`
- **Auth**: Required
- **Request**: None
- **Response**: `{ stats: { characterId: int, ... } }`
- **Service**: Counts conversations per character

### GET /api/v1/chat/characters/favorites
- **URL**: `/api/v1/chat/characters/favorites`
- **Auth**: Required
- **Request**: None
- **Response**: `{ favorites: [str, ...] }`
- **Service**: Query UserFavoriteCharacter

### POST /api/v1/chat/characters/favorites
- **URL**: `/api/v1/chat/characters/favorites`
- **Auth**: Required
- **Request**: `{ characterId: str }`
- **Response**: `{ favorited: bool }` (true = added, false = removed)
- **Service**: Toggle UserFavoriteCharacter

### GET /api/v1/chat/{conversation_id}
- **URL**: `/api/v1/chat/{conversation_id}`
- **Auth**: Required
- **Request**: Path param: conversation_id (UUID)
- **Response**:
  ```
  {
    id: str,
    messages: list,
    feedbackSummary: dict | null,
    messageCount: int,
    type: str (enum),
    createdAt: ISO,
    endedAt: ISO | null
  }
  ```
- **Service**: Query Conversation (verify ownership)

### DELETE /api/v1/chat/{conversation_id}
- **URL**: `/api/v1/chat/{conversation_id}`
- **Auth**: Required
- **Request**: Path param: conversation_id
- **Response**: `{ success: bool }`
- **Service**: Delete Conversation

---

## 8. STATS

### GET /api/v1/stats/dashboard
- **URL**: `/api/v1/stats/dashboard`
- **Auth**: Required
- **Request**: None
- **Response** (DashboardResponse):
  ```
  {
    today: {
      wordsStudied: int,
      quizzesCompleted: int,
      xpEarned: int,
      goalProgress: float (0-1)
    },
    streak: int,
    weekly: {
      dates: [str, ...],
      wordsStudied: [int, ...],
      xpEarned: [int, ...]
    },
    levelProgress: {
      vocabulary: { total, mastered, inProgress },
      grammar: { total, mastered, inProgress }
    },
    kanaProgress: {
      hiragana: { learned, mastered, total },
      katakana: { learned, mastered, total }
    }
  }
  ```
- **Service**: Aggregates DailyProgress, UserVocabProgress, UserGrammarProgress, UserKanaProgress

### GET /api/v1/stats/history
- **URL**: `/api/v1/stats/history?days=30`
- **Auth**: Required
- **Request** (Query):
  - `days` (int, default: 30, max: 90)
- **Response** (HistoryResponse):
  ```
  {
    days: [{
      date: str,
      wordsStudied: int,
      quizzesCompleted: int,
      xpEarned: int
    }, ...]
  }
  ```
- **Service**: Query DailyProgress for past N days

---

## 9. WORDBOOK

### GET /api/v1/wordbook/?page=1&limit=20&sort=recent&search=&source=
- **URL**: `/api/v1/wordbook/`
- **Auth**: Required
- **Request** (Query):
  - `page` (int, default: 1, ge: 1)
  - `limit` (int, default: 20, le: 100)
  - `sort` (str, default: "recent", options: "recent" | "alphabetical")
  - `search` (str | null, optional)
  - `source` (str | null, optional) → uppercase conversion
- **Response** (WordbookListResponse):
  ```
  {
    entries: [WordbookEntryResponse, ...],
    total: int,
    page: int,
    pageSize: int,
    totalPages: int
  }
  ```
- **Service**: Query WordbookEntry with pagination

### POST /api/v1/wordbook/
- **URL**: `/api/v1/wordbook/`
- **Auth**: Required
- **Request** (WordbookCreateRequest):
  - `word` (str)
  - `reading` (str)
  - `meaningKo` (str)
  - `source` (WordbookSource, default: MANUAL)
  - `note` (str | null)
- **Response**: WordbookEntryResponse
- **Service**: Upsert WordbookEntry (on conflict: update reading, meaning_ko, note)
- **Note**: Conflict on (user_id, word)

### GET /api/v1/wordbook/{entry_id}
- **URL**: `/api/v1/wordbook/{entry_id}`
- **Auth**: Required
- **Request**: Path: entry_id (UUID)
- **Response**: WordbookEntryResponse
- **Service**: Query WordbookEntry

### PATCH /api/v1/wordbook/{entry_id}
- **URL**: `/api/v1/wordbook/{entry_id}`
- **Auth**: Required
- **Request** (WordbookUpdateRequest):
  - `note` (str | null)
- **Response**: WordbookEntryResponse
- **Service**: Update WordbookEntry.note

### DELETE /api/v1/wordbook/{entry_id}
- **URL**: `/api/v1/wordbook/{entry_id}`
- **Auth**: Required
- **Request**: Path: entry_id
- **Response**: `{ success: bool }`
- **Service**: Delete WordbookEntry

---

## 10. MISSIONS

### GET /api/v1/missions/today
- **URL**: `/api/v1/missions/today`
- **Auth**: Required
- **Request**: None
- **Response**:
  ```
  [{
    id: str,
    missionType: str,
    targetCount: int,
    currentCount: int,
    isCompleted: bool,
    rewardClaimed: bool,
    xpReward: int
  }, ...]
  ```
- **Service**: Generates 3 deterministic daily missions (hash-based seed), auto-awards completed missions
- **Note**: Missions auto-awarded when currentCount >= targetCount

### POST /api/v1/missions/claim
- **URL**: `/api/v1/missions/claim`
- **Auth**: Required
- **Request** (MissionClaimRequest):
  - `missionId` (UUID)
- **Response** (MissionClaimResponse):
  - `xpReward` (int)
  - `totalXp` (int)
  - `events` (list of achievement events)
- **Service**: Marks mission.reward_claimed = True, awards XP, checks achievements
- **Note**: Idempotent (errors if already claimed or not completed)

---

## 11. SUBSCRIPTION & PAYMENTS

### GET /api/v1/subscription/status
- **URL**: `/api/v1/subscription/status`
- **Auth**: Required
- **Request**: None
- **Response** (SubscriptionStatusResponse):
  ```
  {
    isPremium: bool,
    plan: str (enum: FREE | MONTHLY | YEARLY),
    expiresAt: ISO | null,
    cancelledAt: ISO | null,
    usage: {
      chatCount: int,
      chatSeconds: int,
      callCount: int,
      callSeconds: int
    },
    limits: {
      chatCount: int,
      chatSeconds: int,
      callCount: int,
      callSeconds: int
    }
  }
  ```
- **Service**: get_subscription_status, get_daily_ai_usage

### POST /api/v1/subscription/checkout
- **URL**: `/api/v1/subscription/checkout`
- **Auth**: Required
- **Request** (CheckoutRequest):
  - `plan` (str, "monthly" or "yearly", case-insensitive)
- **Response** (CheckoutResponse):
  - `paymentId` (str) → format: `hk_[plan]_[hex8]_[timestamp]`
  - `storeId` (str)
  - `channelKey` (str)
  - `orderName` (str)
  - `totalAmount` (int, KRW)
  - `currency` (str, "KRW")
  - `customerId` (str)
- **Service**: Creates Payment record, returns PortOne checkout data
- **Note**: Payment status set to PENDING

### POST /api/v1/subscription/activate
- **URL**: `/api/v1/subscription/activate`
- **Auth**: Required
- **Request** (ActivateRequest):
  - `paymentId` (str)
- **Response**:
  ```
  {
    success: bool,
    subscriptionId: str,
    currentPeriodEnd: ISO
  }
  ```
- **Service**: Verifies payment amount, creates Subscription, updates User.is_premium
- **Note**: Calls verify_payment_amount (PortOne)

### POST /api/v1/subscription/cancel
- **URL**: `/api/v1/subscription/cancel`
- **Auth**: Required
- **Request** (CancelRequest):
  - `reason` (str | null)
- **Response**: `{ success: bool }`
- **Service**: cancel_subscription service
- **Note**: Sets subscription.status = "CANCELLED", user.is_premium = False

### POST /api/v1/subscription/resume
- **URL**: `/api/v1/subscription/resume`
- **Auth**: Required
- **Request**: None
- **Response**: `{ success: bool }`
- **Service**: resume_subscription service
- **Note**: Reactivates cancelled subscription

### GET /api/v1/payments/?page=1&page_size=10
- **URL**: `/api/v1/payments/`
- **Auth**: Required
- **Request** (Query):
  - `page` (int, default: 1, ge: 1)
  - `page_size` (int, default: 10, le: 50)
- **Response** (PaymentHistoryResponse):
  ```
  {
    payments: [{
      id: str,
      amount: int,
      currency: str,
      status: str (enum: PENDING | COMPLETED | FAILED | REFUNDED),
      plan: str (enum),
      paidAt: ISO | null,
      createdAt: ISO
    }, ...],
    total: int,
    page: int,
    pageSize: int,
    totalPages: int
  }
  ```
- **Service**: get_payment_history service

---

## 12. WEBHOOK & CRON

### POST /api/v1/webhook/portone
- **URL**: `/api/v1/webhook/portone`
- **Auth**: Not required (signature verified)
- **Request**:
  - Headers: `x-portone-signature`, `x-portone-timestamp`
  - Body: JSON with `data.paymentId`
- **Response**: `{ ok: bool }`
- **Service**: Verifies HMAC signature, finds Payment, activates subscription if PENDING
- **Note**: Idempotent (only processes PENDING payments), timestamp tolerance 5 minutes

### POST /api/v1/cron/subscription-renewal
- **URL**: `/api/v1/cron/subscription-renewal`
- **Auth**: Required (Bearer token in Authorization header)
- **Request**:
  - Header: `Authorization: Bearer {CRON_SECRET}`
- **Response**: `{ processed: int }`
- **Service**: Expires subscriptions past current_period_end, marks user.is_premium = False
- **Note**: Cloud Scheduler endpoint

---

## 13. TTS (Text-to-Speech for Vocabulary)

### POST /api/v1/vocab/tts
- **URL**: `/api/v1/vocab/tts`
- **Auth**: Required
- **Request** (VocabTTSRequest):
  - `id` (str) → vocabulary_id
- **Response**: `{ audioUrl: str }`
- **Service**: Generates TTS using vocabulary.reading, uploads to GCS, updates vocab.audio_url
- **Note**: Rate-limited, prevents duplicate concurrent generation

---

## 14. NOTIFICATIONS

### GET /api/v1/notifications/?limit=20
- **URL**: `/api/v1/notifications/`
- **Auth**: Required
- **Request** (Query):
  - `limit` (int, default: 20, le: 50)
- **Response**:
  ```
  [{
    id: str,
    type: str,
    title: str,
    body: str,
    emoji: str | null,
    isRead: bool,
    createdAt: ISO
  }, ...]
  ```
- **Service**: Query Notification (sorted by is_read, created_at desc)

---

## 15. PUSH NOTIFICATIONS

### POST /api/v1/push/subscribe
- **URL**: `/api/v1/push/subscribe`
- **Auth**: Required
- **Request** (PushSubscribeRequest):
  - `endpoint` (str)
  - `p256dh` (str)
  - `auth` (str)
- **Response**: `{ success: bool }`
- **Service**: Upsert PushSubscription
- **Note**: Conflict on (user_id, endpoint)

---

## 16. STUDY

### GET /api/v1/study/learned-words?page=1&limit=20
- **URL**: `/api/v1/study/learned-words`
- **Auth**: Required
- **Request** (Query):
  - `page` (int, default: 1, ge: 1)
  - `limit` (int, default: 20, le: 50)
- **Response**:
  ```
  {
    words: [{
      id: str,
      word: str,
      reading: str,
      meaningKo: str,
      jlptLevel: str,
      partOfSpeech: str
    }, ...],
    total: int,
    page: int,
    pageSize: int
  }
  ```
- **Service**: Query Vocabulary where UserVocabProgress exists

### GET /api/v1/study/wrong-answers?page=1&limit=20
- **URL**: `/api/v1/study/wrong-answers`
- **Auth**: Required
- **Request** (Query):
  - `page` (int, default: 1, ge: 1)
  - `limit` (int, default: 20, le: 50)
- **Response**:
  ```
  {
    wrongAnswers: [{
      questionId: str,
      questionType: str,
      selectedOptionId: str,
      answeredAt: ISO
    }, ...]
  }
  ```
- **Service**: Query QuizAnswer where is_correct = False

---

## KEY MODELS & ENUMS

### Enums (from app/models/enums.py)
- **JlptLevel**: N1, N2, N3, N4, N5
- **QuizType**: VOCABULARY, KANJI, LISTENING, GRAMMAR, KANA
- **ConversationType**: TEXT, VOICE
- **UserGoal**: JLPT_PREPARATION, CASUAL_LEARNING, BUSINESS, TRAVEL
- **WordbookSource**: MANUAL, QUIZ, CHAT, KANA
- **PaymentStatus**: PENDING, COMPLETED, FAILED, REFUNDED
- **SubscriptionPlan**: FREE, MONTHLY, YEARLY
- **KanaType**: HIRAGANA, KATAKANA
- **ScenarioCategory**: (various, from DB)
- **Difficulty**: (various, from DB)

### Authentication
- All endpoints marked "Required" depend on `get_current_user` middleware
- Gets User from JWT token (Supabase Auth)
- Returns 401 if token invalid/expired

### Rate Limiting
- AI endpoints use `rate_limit(f"endpoint:{user_id}", max_requests, window_seconds)`
- TTS: AI limits (max_requests per window_seconds)
- Chat: check_ai_limit (subscription-based limits)
- Live token: LIVE_TOKEN specific limits

### Field Naming Convention
- All Pydantic models using `CamelModel` auto-convert snake_case ↔ camelCase
- Database columns: snake_case
- Request/Response JSON: camelCase
- Example: `session_id` (DB) → `sessionId` (JSON)

---

## Response Status Codes
- **200**: Success
- **201**: Created (POST returning resource)
- **400**: Bad request (validation error, conflict, etc.)
- **401**: Unauthorized (invalid token, missing auth)
- **404**: Not found (resource doesn't exist)
- **409**: Conflict (e.g., duplicate concurrent TTS generation)
- **429**: Rate limited or over quota
- **500**: Server error

---

## Error Response Format
```json
{
  "detail": "Error message string"
}
```
