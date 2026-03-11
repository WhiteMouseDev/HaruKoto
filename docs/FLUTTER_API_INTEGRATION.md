# Flutter ↔ FastAPI 연동 가이드

> **작성일**: 2026-03-11
> **API 서버**: `https://harukoto-api-842843944454.asia-northeast3.run.app`
> **OpenAPI Docs**: `{BASE_URL}/docs`
> **OpenAPI JSON**: `{BASE_URL}/openapi.json`

---

## 1. 인증 플로우

### 1.1 전체 흐름

```
[Flutter App]                    [Supabase Auth]              [FastAPI]
     │                                │                          │
     ├── 로그인 (Google/Kakao/Email) ──→                          │
     │                                ├── JWT 발급 ──→            │
     ←── Access Token + Refresh Token ─┤                          │
     │                                                            │
     ├── API 요청 (Authorization: Bearer {token}) ──────────────→ │
     │                                                            ├── JWKS로 JWT 검증
     │                                                            ├── DB에서 유저 조회
     ←────────────────── 응답 ────────────────────────────────────┤
```

### 1.2 Supabase Auth 초기화

```dart
// supabase_flutter 사용
await Supabase.initialize(
  url: 'https://tdimppgykstgeykbnwal.supabase.co',
  anonKey: 'YOUR_ANON_KEY',
);

final supabase = Supabase.instance.client;
```

### 1.3 로그인

```dart
// Google 로그인
final response = await supabase.auth.signInWithOAuth(OAuthProvider.google);

// Kakao 로그인
final response = await supabase.auth.signInWithOAuth(OAuthProvider.kakao);

// 이메일 로그인
final response = await supabase.auth.signInWithPassword(
  email: 'user@example.com',
  password: 'password',
);
```

### 1.4 토큰 관리

```dart
// 현재 토큰 가져오기
String? get accessToken => supabase.auth.currentSession?.accessToken;

// 토큰 만료 시 자동 갱신 (supabase_flutter가 처리)
supabase.auth.onAuthStateChange.listen((data) {
  if (data.event == AuthChangeEvent.tokenRefreshed) {
    // 새 토큰으로 갱신됨
  }
});
```

### 1.5 Dio 인터셉터 설정

```dart
final dio = Dio(BaseOptions(
  baseUrl: 'https://harukoto-api-842843944454.asia-northeast3.run.app/api/v1',
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 30),
));

dio.interceptors.add(InterceptorsWrapper(
  onRequest: (options, handler) {
    final token = supabase.auth.currentSession?.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  },
  onError: (error, handler) async {
    if (error.response?.statusCode == 401) {
      // 토큰 갱신 시도
      await supabase.auth.refreshSession();
      final newToken = supabase.auth.currentSession?.accessToken;
      if (newToken != null) {
        error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
        final response = await dio.fetch(error.requestOptions);
        return handler.resolve(response);
      }
    }
    return handler.next(error);
  },
));
```

---

## 2. 에러 코드 맵

### 2.1 HTTP 상태 코드

| 코드 | 의미 | Flutter 처리 |
|------|------|-------------|
| `200` | 성공 | 정상 처리 |
| `201` | 생성 성공 | 정상 처리 (단어장 추가 등) |
| `400` | 잘못된 요청 | 입력값 검증 에러 표시 |
| `401` | 인증 실패 | 토큰 갱신 → 실패 시 로그인 화면으로 |
| `404` | 리소스 없음 | "찾을 수 없습니다" 표시 |
| `409` | 충돌 | TTS 생성 중 중복 요청 등 |
| `422` | 유효성 검증 실패 | 필드별 에러 메시지 표시 |
| `429` | 요청 한도 초과 | "잠시 후 다시 시도해주세요" + Retry-After 헤더 참고 |
| `500` | 서버 에러 | "일시적 오류입니다" 표시 |

### 2.2 에러 응답 형식

```json
{
  "detail": "대화를 찾을 수 없습니다"
}
```

또는 유효성 검증 에러:

```json
{
  "detail": [
    {
      "loc": ["body", "message"],
      "msg": "field required",
      "type": "value_error.missing"
    }
  ]
}
```

### 2.3 Flutter 에러 핸들링

```dart
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
}

// Dio 에러 인터셉터
dio.interceptors.add(InterceptorsWrapper(
  onError: (error, handler) {
    final detail = error.response?.data?['detail'];
    final message = detail is String ? detail : '일시적 오류입니다';

    switch (error.response?.statusCode) {
      case 401:
        // 토큰 갱신 로직 (위 1.5 참고)
        break;
      case 429:
        // Rate limit - 재시도 타이머 표시
        break;
      default:
        throw ApiException(error.response?.statusCode ?? 0, message);
    }
    return handler.next(error);
  },
));
```

---

## 3. 핵심 유저 플로우

### 3.1 온보딩 (최초 가입)

```
1. Supabase 로그인 (Google/Kakao)
2. POST /auth/onboarding
   Body: { "nickname": "하루", "jlptLevel": "N5", "goal": "JLPT_N5" }
   → 201 Created
3. 가나 학습 화면으로 이동
```

### 3.2 퀴즈 풀기

```
1. POST /quiz/start
   Body: { "quizType": "VOCABULARY", "jlptLevel": "N5", "count": 10, "mode": "normal" }
   → { sessionId, questions: [...], totalQuestions: 10 }

2. (반복) POST /quiz/answer
   Body: { "sessionId": "...", "questionId": "...", "selectedOptionId": "...", "timeSpentSeconds": 5 }
   → { correct: true, correctOptionId: "...", explanation: "..." }

3. POST /quiz/complete
   Body: { "sessionId": "..." }
   → { correctCount: 8, accuracy: 80.0, xpEarned: 80, events: [...] }

4. events 배열에서 레벨업/업적 달성 확인 → 축하 팝업 표시
```

### 3.3 AI 채팅 (텍스트)

```
1. POST /chat/start
   Body: { "scenarioId": "...", "type": "TEXT" }
   → { conversationId, firstMessage: { messageJa, messageKo, hint } }

2. (반복) POST /chat/message
   Body: { "conversationId": "...", "message": "こんにちは" }
   → { messageJa, messageKo, feedback: [...], hint, newVocabulary: [...] }

3. POST /chat/end
   Body: { "conversationId": "..." }
   → { success: true, feedbackSummary: {...}, xpEarned: 20, events: [...] }
```

### 3.4 AI 음성 통화

```
1. POST /chat/live-token
   → { token: "...", wsUri: "wss://..." }

2. WebSocket으로 Gemini Live API에 직접 연결 (token 사용)
   - 녹음: record 패키지
   - 재생: just_audio 패키지
   - 실시간 스트리밍

3. 통화 종료 후:
   POST /chat/live-feedback
   Body: { "conversationId": "...", "duration": 120 }
   → { feedbackSummary: {...}, xpEarned: 20, events: [...] }
```

### 3.5 TTS (음성 재생)

```
POST /chat/tts
Body: { "text": "こんにちは", "voiceName": "Kore" }
→ audio/wav (binary)

// Flutter에서 재생
final response = await dio.post('/chat/tts',
  data: { 'text': text },
  options: Options(responseType: ResponseType.bytes),
);
final player = AudioPlayer();
await player.setAudioSource(MyCustomSource(response.data));
await player.play();
```

### 3.6 단어장 관리

```
# 목록 조회
GET /wordbook/?page=1&limit=20
→ { items: [...], total: 42, page: 1, pageSize: 20, totalPages: 3 }

# 단어 추가
POST /wordbook/
Body: { "word": "食べる", "reading": "たべる", "meaningKo": "먹다", "source": "MANUAL" }
→ 201 Created

# 삭제
DELETE /wordbook/{id}
→ 200 OK
```

### 3.7 구독/결제

```
# 상태 확인
GET /subscription/status
→ { isPremium, plan, usage: { chatCount, callCount, ... }, limits: { ... } }

# 결제 (PortOne → 앱에서는 IAP 필요)
# Apple/Google 스토어 정책상 디지털 구독은 In-App Purchase 필수
# IAP 결제 완료 후:
POST /subscription/activate
Body: { "paymentId": "iap_xxx", "plan": "MONTHLY" }
```

---

## 4. API 전체 엔드포인트 목록

### 인증
| Method | Endpoint | 설명 |
|--------|----------|------|
| `POST` | `/auth/onboarding` | 온보딩 완료 |

### 유저
| Method | Endpoint | 설명 |
|--------|----------|------|
| `GET` | `/user/profile` | 프로필 + 통계 조회 |
| `PATCH` | `/user/profile` | 설정 변경 |
| `PATCH` | `/user/avatar` | 아바타 변경 |
| `PATCH` | `/user/account` | 닉네임/이메일 변경 |

### 퀴즈
| Method | Endpoint | 설명 |
|--------|----------|------|
| `POST` | `/quiz/start` | 퀴즈 시작 |
| `POST` | `/quiz/answer` | 답변 제출 |
| `POST` | `/quiz/complete` | 퀴즈 완료 |
| `GET` | `/quiz/resume` | 미완료 퀴즈 이어하기 |
| `GET` | `/quiz/stats` | 퀴즈 통계 |
| `GET` | `/quiz/recommendations` | 추천 퀴즈 |
| `GET` | `/quiz/wrong-answers/{session_id}` | 오답 목록 |

### 가나
| Method | Endpoint | 설명 |
|--------|----------|------|
| `GET` | `/kana/characters` | 가나 문자 목록 (인증 불필요) |
| `GET` | `/kana/stages` | 학습 스테이지 |
| `GET` | `/kana/progress` | 가나 진행률 |
| `POST` | `/kana/progress` | 가나 학습 기록 |
| `POST` | `/kana/quiz/start` | 가나 퀴즈 시작 |
| `POST` | `/kana/quiz/answer` | 가나 퀴즈 답변 |
| `POST` | `/kana/stage-complete` | 스테이지 완료 |

### AI 채팅
| Method | Endpoint | 설명 |
|--------|----------|------|
| `POST` | `/chat/start` | 대화 시작 |
| `POST` | `/chat/message` | 메시지 전송 |
| `POST` | `/chat/end` | 대화 종료 |
| `POST` | `/chat/tts` | TTS 음성 생성 |
| `POST` | `/chat/voice/transcribe` | 음성 인식 (STT) |
| `POST` | `/chat/live-token` | 실시간 통화 토큰 |
| `POST` | `/chat/live-feedback` | 통화 피드백 |

### 채팅 데이터
| Method | Endpoint | 설명 |
|--------|----------|------|
| `GET` | `/chat-data/scenarios` | 시나리오 목록 |
| `GET` | `/chat-data/characters` | AI 캐릭터 목록 |
| `GET` | `/chat-data/history` | 대화 기록 |
| `GET` | `/chat-data/character-stats/{id}` | 캐릭터 통계 |
| `POST` | `/chat-data/favorites` | 시나리오 즐겨찾기 |
| `DELETE` | `/chat-data/favorites/{id}` | 즐겨찾기 해제 |

### 통계
| Method | Endpoint | 설명 |
|--------|----------|------|
| `GET` | `/stats/dashboard` | 대시보드 (오늘 학습, 주간, 레벨) |
| `GET` | `/stats/history?days=30` | 일별 학습 기록 |

### 학습 데이터
| Method | Endpoint | 설명 |
|--------|----------|------|
| `GET` | `/study/learned-words` | 학습한 단어 목록 |
| `GET` | `/study/wrong-answers` | 오답 단어 목록 |

### 미션
| Method | Endpoint | 설명 |
|--------|----------|------|
| `GET` | `/missions/today` | 오늘의 미션 3개 |
| `POST` | `/missions/claim` | 미션 보상 수령 |

### 단어장
| Method | Endpoint | 설명 |
|--------|----------|------|
| `GET` | `/wordbook/` | 단어장 목록 (페이지네이션) |
| `POST` | `/wordbook/` | 단어 추가 |
| `GET` | `/wordbook/{id}` | 단어 상세 |
| `PATCH` | `/wordbook/{id}` | 단어 수정 |
| `DELETE` | `/wordbook/{id}` | 단어 삭제 |

### 구독/결제
| Method | Endpoint | 설명 |
|--------|----------|------|
| `GET` | `/subscription/status` | 구독 상태 + AI 사용량 |
| `POST` | `/subscription/checkout` | 결제 세션 생성 |
| `POST` | `/subscription/activate` | 구독 활성화 |
| `POST` | `/subscription/cancel` | 구독 취소 |
| `POST` | `/subscription/resume` | 구독 재개 |

### 단어 TTS
| Method | Endpoint | 설명 |
|--------|----------|------|
| `POST` | `/vocab/tts` | 단어 발음 듣기 (GCS 캐싱) |

### 알림
| Method | Endpoint | 설명 |
|--------|----------|------|
| `GET` | `/notifications/` | 알림 목록 |
| `POST` | `/push/subscribe` | 푸시 구독 등록 |

### 결제 내역
| Method | Endpoint | 설명 |
|--------|----------|------|
| `GET` | `/payments/` | 결제 내역 |

---

## 5. 데이터 타입 (Enum)

모든 API 요청/응답은 **camelCase** JSON입니다.

```dart
enum JlptLevel { N5, N4, N3, N2, N1 }

enum QuizType { VOCABULARY, GRAMMAR, KANJI, LISTENING, KANA, CLOZE, SENTENCE_ARRANGE }

enum QuizMode { normal, review, cloze, arrange }

enum KanaType { HIRAGANA, KATAKANA }

enum ScenarioCategory { TRAVEL, DAILY, BUSINESS, FREE }

enum Difficulty { BEGINNER, INTERMEDIATE, ADVANCED }

enum ConversationType { VOICE, TEXT }

enum WordbookSource { QUIZ, CONVERSATION, MANUAL }

enum SubscriptionPlan { FREE, MONTHLY, YEARLY }

enum UserGoal { JLPT_N5, JLPT_N4, JLPT_N3, JLPT_N2, JLPT_N1, TRAVEL, BUSINESS, HOBBY }
```

---

## 6. Rate Limits

| 카테고리 | 제한 | 윈도우 |
|---------|------|--------|
| AI (채팅/TTS) | 20회 | 60초 |
| 일반 API | 60회 | 60초 |
| 인증 | 10회 | 60초 |
| 실시간 통화 토큰 | 5회 | 60초 |

429 응답 시 `Retry-After` 헤더를 확인하세요.

---

## 7. AI 사용 제한 (일일)

| | 무료 | 프리미엄 |
|---|---|---|
| 채팅 횟수 | 3회/일 | 50회/일 |
| 채팅 시간 | 300초/일 | 600초/일 |
| 통화 횟수 | 1회/일 | 20회/일 |
| 통화 시간 | 180초/일 | 600초/일 |

`GET /subscription/status`에서 `usage`와 `limits`를 비교하여 제한 도달 여부를 판단하세요.
