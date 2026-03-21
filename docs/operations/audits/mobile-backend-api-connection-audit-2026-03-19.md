# Mobile ↔ Backend API Connection Audit (2026-03-19)

## 1) 결론 요약
- **현재 상태는 "부분 연결"** 입니다.
- 핵심 플로우 기준으로 보면:
  - 홈/통계/학습(일부)/프로필/알림/단어장/TTS는 대체로 연결됨
  - **채팅(시나리오/음성피드백), 가나 퀴즈, 결제내역, 오답 세션 조회**에서 계약 불일치가 존재함
- 즉시 수정이 필요한 **P0/P1 이슈 8건** 확인

---

## 2) 검증 범위
- Mobile: `apps/mobile/lib` 내 Dio 호출과 파싱 모델
- Backend: `apps/api/app/routers`, `apps/api/app/schemas`, 일부 `services`
- 검증 항목:
  - HTTP Method + Path
  - Query/Body 필드명
  - Response shape/casing/type
  - 실제 화면 플로우에서 호출되는지 여부

---

## 3) 불일치 매트릭스 (중요도 순)

| Priority | 영역 | Mobile 호출 | Backend 계약 | 판정 | 영향 |
|---|---|---|---|---|---|
| P0 | Chat | `GET /chat/scenarios`를 `Map{scenarios:[]}`로 파싱 | 서버는 **리스트 직접 반환** | ❌ Broken | 시나리오 목록 로딩 실패 가능 |
| P0 | Chat | `GET /chat/characters/{id}` | 서버는 `GET /chat/characters?id=...`만 지원 | ❌ Broken | 음성통화 캐릭터 상세 로딩 실패(404) |
| P0 | Chat | `POST /chat/live-feedback`에 `transcript,durationSeconds,...` 전송 | 서버는 `conversationId,durationSeconds` 필수 | ❌ Broken | 통화 후 피드백 저장/조회 실패 |
| P0 | Kana | `POST /kana/quiz/complete` | 해당 라우트 없음 | ❌ Broken | 가나 퀴즈 완료 시 실패 |
| P0 | Kana | `POST /kana/stage-complete` body=`stageId,quizScore` | 서버는 `kanaType,stageNumber,score` 필요 | ❌ Broken | 스테이지 완료 반영 실패(422) |
| P1 | Kana | 가나 마스터 퀴즈 시작 시 `stageNumber` 누락 | 서버는 `stageNumber` 필수 | ⚠️ Risk | 특정 퀴즈 시작 실패(422) |
| P1 | Quiz | `GET /quiz/wrong-answers?sessionId=...` | 서버는 `session_id` 파라미터 사용 | ❌ Broken | 세션 오답 조회 실패 |
| P1 | Payments | 모바일은 `paidAt/createdAt/totalPages` 기대 | 서버는 `paid_at/created_at/total_pages` 반환 | ⚠️ Degraded | 날짜/페이지네이션 오동작 |
| P1 | Quiz Result | 모바일 `accuracy`를 `int`로 캐스팅 | 서버 `accuracy`는 `float` | ⚠️ Risk | 완료 응답 파싱 오류 가능 |
| P2 | Chat Detail | 모바일 메시지 모델 `messageJa/messageKo` 기대 | 서버 저장 메시지 `role/content` 구조 반환 | ⚠️ Degraded | 과거 대화 로딩 시 메시지 빈값 표시 가능 |
| P2 | Kana Progress | 모바일 `pct` 사용 | 서버 `kana/progress`는 `pct` 미제공 | ⚠️ Degraded | 진행률 UI 0% 고정 가능 |
| P3 | Subscription | 모바일 코드에 `/subscription/subscribe` 호출 존재 | 서버는 `/checkout,/activate,...`만 제공 | ⚠️ Dead path | 현재 UI 미사용이나 잠재 결함 |

---

## 4) 근거 (파일 기준)

### 4.1 Chat 시나리오 응답 shape 불일치 (P0)
- Mobile
  - `apps/mobile/lib/features/chat/data/chat_repository.dart:15-22`
  - `response.data['scenarios']`를 기대
- Backend
  - `apps/api/app/routers/chat_data.py:24-49`
  - 리스트를 직접 반환 (`return [ ... ]`)

### 4.2 Chat 캐릭터 상세 경로 불일치 (P0)
- Mobile
  - `apps/mobile/lib/features/chat/data/chat_repository.dart:84-89`
  - `GET /chat/characters/$characterId`
- Backend
  - `apps/api/app/routers/chat_data.py:116-124`
  - `GET /chat/characters?id=...`만 지원

### 4.3 Live feedback 계약 불일치 (P0)
- Mobile 호출
  - `apps/mobile/lib/features/chat/data/chat_repository.dart:128-143`
  - `transcript`, `durationSeconds`, `scenarioId`, `characterId`
- Backend 요구
  - `apps/api/app/schemas/chat.py:96-98` (`conversation_id`, `duration_seconds`)
  - `apps/api/app/routers/chat.py:368-379` (conversation 조회 필수)
- 실제 플로우
  - `apps/mobile/lib/features/chat/presentation/call_analyzing_page.dart:63-68`
  - conversationId를 보내지 않음

### 4.4 Kana 퀴즈 완료 라우트 부재 (P0)
- Mobile
  - `apps/mobile/lib/features/kana/data/kana_repository.dart:95-103`
  - `POST /kana/quiz/complete`
- Backend
  - `apps/api/app/routers/kana.py`에 해당 라우트 없음

### 4.5 Kana stage-complete body 불일치 (P0)
- Mobile
  - `apps/mobile/lib/features/kana/data/kana_repository.dart:52-59`
  - `{stageId, quizScore}`
- Backend
  - `apps/api/app/schemas/kana.py:76-80`
  - `{kanaType, stageNumber, score}` 요구

### 4.6 Kana master quiz 시작 파라미터 누락 (P1)
- Mobile
  - `apps/mobile/lib/features/kana/presentation/kana_quiz_page.dart:59-63`
  - `startQuiz()` 호출 시 `stageNumber` 없음
- Backend
  - `apps/api/app/schemas/kana.py:52-56`
  - `stage_number` 필수
- 참고: `kana_stage_page` 경로는 stageNumber를 전달하고 있어 정상 가능
  - `apps/mobile/lib/features/kana/presentation/kana_stage_page.dart:273-277`

### 4.7 Quiz wrong-answers query key 불일치 (P1)
- Mobile
  - `apps/mobile/lib/features/study/data/study_repository.dart:194-197`
  - `sessionId`
- Backend
  - `apps/api/app/routers/quiz.py:1047`
  - `session_id`

### 4.8 Payments 응답 케이스 불일치 (P1)
- Mobile 기대
  - `apps/mobile/lib/features/my/data/my_repository.dart:62` (`totalPages`)
  - `apps/mobile/lib/features/my/data/models/payment_model.dart:24-25` (`paidAt`, `createdAt`)
- Backend 실제
  - `apps/api/app/services/subscription.py:313-315,321`
  - `paid_at`, `created_at`, `total_pages`

### 4.9 Quiz complete accuracy 타입 불일치 (P1)
- Mobile
  - `apps/mobile/lib/features/study/data/models/quiz_result_model.dart:50`
  - `accuracy`를 `int`로 강캐스팅
- Backend
  - `apps/api/app/schemas/quiz.py:79` (`accuracy: float`)
  - `apps/api/app/routers/quiz.py:724,804` (float 계산)

### 4.10 Conversation detail 메시지 shape 불일치 (P2)
- Mobile
  - `apps/mobile/lib/features/chat/data/models/chat_message_model.dart:20-21`
  - `messageJa/messageKo` 기대
- Backend
  - `apps/api/app/routers/chat_data.py:245-253`
  - `messages`는 저장된 `role/content` 원형 반환

### 4.11 Kana progress pct 미제공 (P2)
- Mobile
  - `apps/mobile/lib/features/kana/data/models/kana_progress_model.dart:24,38`
  - `pct` 사용
- Backend
  - `apps/api/app/schemas/kana.py:23-44`
  - `learned/mastered/total`만 제공

### 4.12 Subscription subscribe dead path (P3)
- Mobile
  - `apps/mobile/lib/features/subscription/data/subscription_repository.dart:15-19`
  - `/subscription/subscribe`
- Backend
  - `apps/api/app/routers/subscription.py:70+`
  - `/checkout`, `/activate`, `/cancel`, `/resume`
- 현재 결제 UI는 준비중으로 즉시 런타임 영향은 낮음
  - `apps/mobile/lib/features/subscription/presentation/checkout_page.dart:47`

---

## 5) 정상 연결로 확인된 영역
- `stats/*` 주요 조회 계열 (dashboard/history/heatmap/jlpt/time/volume/by-category)
- `user/profile` 조회/수정, `study/daily-goal`
- `wordbook` CRUD(트레일링 슬래시 리다이렉트 가능성은 있으나 기능적으로 동작)
- `notifications` 조회/읽음 처리
- `missions/today`
- `vocab/tts`, `kana/tts`
- `auth/kakao/exchange`, `auth/onboarding`

---

## 6) 수정 우선순위 제안

### 즉시 수정 (오늘)
1. Chat scenarios 파싱을 리스트 응답 기준으로 수정
2. Chat character detail 호출을 `GET /chat/characters?id=`로 변경
3. Live feedback 계약 통일 (모바일에서 `conversationId` 전달 또는 서버 계약 변경)
4. Kana `quiz/complete` 경로 정합성 맞추기 (`/quiz/complete` 재사용 또는 백엔드 라우트 추가)
5. Kana `stage-complete` body를 서버 스키마와 맞춤
6. Quiz wrong-answers query key를 `session_id`로 변경

### 단기 개선 (1~2일)
1. Payments snake_case ↔ camelCase 정합성 통일
2. `accuracy` / 점수 필드를 `num` 파싱 후 안전 변환
3. Conversation detail 메시지 shape 어댑터 추가
4. Kana progress `pct` 계산/제공 로직 일치

### 중기 개선 (1주)
1. API contract test(모바일 DTO ↔ FastAPI 스키마) CI에 추가
2. OpenAPI 기반 타입 생성(혹은 공통 계약 문서 자동검증) 도입
3. 라우트/DTO 변경 시 breaking 체크 자동화

---

## 7) 최소 수정 예시 (모바일)

### A. wrong-answers 쿼리키 수정
```dart
// before
queryParameters: {'sessionId': sessionId}

// after
queryParameters: {'session_id': sessionId}
```

### B. payments snake_case 대응
```dart
// before
totalPages: data['totalPages'] as int? ?? 1,
paidAt: json['paidAt'] as String?,
createdAt: json['createdAt'] as String?,

// after
totalPages: (data['totalPages'] ?? data['total_pages']) as int? ?? 1,
paidAt: (json['paidAt'] ?? json['paid_at']) as String?,
createdAt: (json['createdAt'] ?? json['created_at']) as String?,
```

### C. quiz result accuracy 안전 파싱
```dart
// before
accuracy: json['accuracy'] as int? ?? 0,

// after
accuracy: (json['accuracy'] as num?)?.round() ?? 0,
```

---

## 8) 최종 판단
- "백엔드와 모바일 API가 전반적으로 연결되어 있다"고 보기는 어렵습니다.
- 특히 **채팅/가나/결제내역 일부**는 계약이 어긋나 있어 실사용 플로우에서 실패 가능성이 높습니다.
- 다만 구조 자체는 정리되어 있어, 위 P0/P1을 정리하면 **단기간에 안정화 가능**한 상태입니다.
