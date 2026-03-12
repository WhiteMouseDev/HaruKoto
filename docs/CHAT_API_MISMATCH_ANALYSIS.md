# Chat/Conversation API 불일치 분석 보고서

**분석 일시**: 2026-03-12
**분석자**: Backend API 전문가
**버전**: Phase 0 (Flutter 네이티브 앱)

## 목차
1. [분석 요약](#분석-요약)
2. [모바일 API 호출 목록](#모바일-api-호출-목록)
3. [백엔드 엔드포인트 목록](#백엔드-엔드포인트-목록)
4. [1:1 불일치 분석](#11-불일치-분석)
5. [필드 매핑 상세 분석](#필드-매핑-상세-분석)
6. [권장 수정 사항](#권장-수정-사항)

---

## 분석 요약

### 발견된 주요 이슈

| 심각도 | 카테고리 | 개수 | 영향 |
|--------|--------|------|------|
| **CRITICAL** | 응답 필드명 불일치 | 3 | 앱 크래시 위험 |
| **HIGH** | 응답 구조 불일치 | 2 | 데이터 파싱 실패 |
| **MEDIUM** | 요청 필드명 불일치 | 1 | 백엔드 에러 응답 |
| **LOW** | 선택 필드 처리 | 1 | 부분 기능 실패 |

### 전체 엔드포인트 매칭 현황

- **총 엔드포인트**: 12개
- **완벽 일치**: 7개
- **필드명 불일치**: 3개 (CRITICAL)
- **응답 구조 불일치**: 2개 (HIGH)

---

## 모바일 API 호출 목록

### 파일: `/apps/mobile/lib/features/chat/data/chat_repository.dart`

| # | 메서드 | URL | Request Body | Response 파싱 |
|---|--------|-----|--------------|--------------|
| 1 | GET | `/chat/scenarios` | query: `category` | `['scenarios']` |
| 2 | GET | `/chat/history` | query: `limit, cursor` | `['history', 'nextCursor']` |
| 3 | DELETE | `/chat/{conversationId}` | - | - |
| 4 | POST | `/chat/start` | `{scenarioId, [characterId], [type]}` | `['conversationId', 'firstMessage']` |
| 5 | GET | `/chat/{conversationId}` | - | `['messages', 'scenario', 'endedAt', 'feedbackSummary']` |
| 6 | POST | `/chat/message` | `{conversationId, message}` | `['messageJa', 'messageKo', 'feedback', 'hint', 'newVocabulary']` |
| 7 | POST | `/chat/end` | `{conversationId}` | `['success', 'feedbackSummary']` |
| 8 | GET | `/chat/characters` | - | `['characters']` |
| 9 | GET | `/chat/characters/stats` | - | `['characterStats']` |
| 10 | GET | `/chat/characters/favorites` | - | `['favoriteIds']` |
| 11 | POST | `/chat/characters/favorites` | `{characterId}` | `['favorited']` |
| 12 | POST | `/chat/live-feedback` | `{transcript, durationSeconds, [scenarioId], [characterId]}` | `['conversationId', 'feedbackSummary']` |

---

## 백엔드 엔드포인트 목록

### 파일: `/apps/api/app/routers/chat_data.py` & `/apps/api/app/routers/chat.py`

| # | 메서드 | URL | 응답 필드 |
|---|--------|-----|----------|
| 1 | GET | `/api/v1/chat/scenarios` | `scenarios[]` |
| 2 | GET | `/api/v1/chat/history` | `{history[], nextCursor}` |
| 3 | DELETE | `/api/v1/chat/{conversation_id}` | `{success}` |
| 4 | POST | `/api/v1/chat/start` | `{conversationId, firstMessage}` |
| 5 | GET | `/api/v1/chat/{conversation_id}` | `{id, messages, feedbackSummary, ...}` |
| 6 | POST | `/api/v1/chat/message` | `{messageJa, messageKo, feedback, hint, newVocabulary}` |
| 7 | POST | `/api/v1/chat/end` | `{success, feedbackSummary, xpEarned, events}` |
| 8 | GET | `/api/v1/chat/characters` | `characters[]` (배열 직접 반환) |
| 9 | GET | `/api/v1/chat/characters/stats` | `{stats}` |
| 10 | GET | `/api/v1/chat/characters/favorites` | `{favorites}` |
| 11 | POST | `/api/v1/chat/characters/favorites` | `{favorited}` |
| 12 | POST | `/api/v1/chat/live-feedback` | `{success, conversationId, feedbackSummary, xpEarned, events}` |

---

## 1:1 불일치 분석

### ✅ ENDPOINT #1: GET `/chat/scenarios` - 완벽 일치

**모바일**: `/chat/scenarios` (라인 18)
**백엔드**: `/api/v1/chat/scenarios` (chat_data.py:23)

**상태**: ✅ 일치

| 항목 | 모바일 | 백엔드 | 일치 |
|------|--------|--------|------|
| URL | `/chat/scenarios` | `/api/v1/chat/scenarios` | ✅ (prefix 제외) |
| 메서드 | GET | GET | ✅ |
| Query 파라미터 | `category` | 미지원 | ⚠️ |
| 응답 필드 | `['scenarios']` | `scenarios: []` | ✅ |

**분석**:
- 모바일이 `?category=` 쿼리를 보내도 백엔드에서 처리하지 않음
- 백엔드 코드 (chat_data.py:25-26)를 보면 `category` 필터가 없음
- 모바일 코드 (line 16): `'?category=$category'` 조건부 추가하지만 무시됨

**영향**: 낮음 - 필터링이 안 되지만 크래시하지 않음

---

### ❌ ENDPOINT #2: GET `/chat/history` - 응답 필드명 불일치 (CRITICAL)

**모바일**: `/chat/history` (라인 31)
**백엔드**: `/api/v1/chat/history` (chat_data.py:48)

**상태**: ❌ CRITICAL - 응답 필드명 불일치

| 항목 | 모바일 | 백엔드 | 일치 |
|------|--------|--------|------|
| URL | `/chat/history` | `/api/v1/chat/history` | ✅ |
| 메서드 | GET | GET | ✅ |
| Query 파라미터 | `limit, cursor` | `limit, cursor` | ✅ |
| 응답 구조 | `{history: [], nextCursor}` | `{history: [], nextCursor}` | ✅ |
| **history[].fields** | | | |
| - `type` | 사용 | **없음** | ❌ |
| - `createdAt` | 사용 | ✅ `createdAt` | ✅ |
| - `endedAt` | 사용 | ✅ `endedAt` | ✅ |
| - `messageCount` | 사용 | ✅ `messageCount` | ✅ |
| - `overallScore` | 사용 | ⚠️ `overallScore` (float) | ⚠️ |

**문제 1: `type` 필드 부재**

모바일 코드 (conversation_model.dart:25):
```dart
type: json['type'] as String? ?? 'TEXT',
```

백엔드 코드 (chat_data.py:68-87):
```python
history.append({
    "id": str(c.id),
    "scenarioTitle": scenario.title if scenario else None,
    ...
    "messageCount": c.message_count,
    "overallScore": feedback.get("overallScore"),
    "createdAt": c.created_at.isoformat(),
    "endedAt": c.ended_at.isoformat() if c.ended_at else None,
})
```

**백엔드에서 `type` 필드를 반환하지 않음!**

**문제 2: `overallScore` 타입 불일치**

모바일 (conversation_model.dart:7, 29):
```dart
final int? overallScore;
```

백엔드:
```python
"overallScore": feedback.get("overallScore") if isinstance(feedback, dict) else None,
```

- 백엔드에서 `feedback` 딕셔너리에서 값을 읽음 → `float` 또는 `int`일 수 있음
- 모바일은 `int`로 강제 변환 → **타입 불일치 가능성**

**영향**:
- `type` 필드 부재로 모바일이 기본값 `'TEXT'`를 사용 → 실제 대화 타입 손실 (VOICE/TEXT 구분 불가)
- `overallScore` 타입 불일치는 파싱 에러 위험

**심각도**: 🔴 **CRITICAL**

---

### ✅ ENDPOINT #3: DELETE `/chat/{conversationId}` - 완벽 일치

**모바일**: `/chat/$conversationId` (라인 36)
**백엔드**: `/api/v1/chat/{conversation_id}` (chat_data.py:198)

**상태**: ✅ 일치

| 항목 | 모바일 | 백엔드 | 일치 |
|------|--------|--------|------|
| URL | `/chat/{id}` | `/api/v1/chat/{id}` | ✅ |
| 메서드 | DELETE | DELETE | ✅ |
| 응답 필드 | - | `{success}` | ✅ |

**분석**: 완벽 일치. 응답값을 사용하지 않음.

---

### ✅ ENDPOINT #4: POST `/chat/start` - 완벽 일치

**모바일**: `/chat/start` (라인 44)
**백엔드**: `/api/v1/chat/start` (chat.py:53)

**상태**: ✅ 일치

| 항목 | 모바일 | 백엔드 | 일치 |
|------|--------|--------|------|
| URL | `/chat/start` | `/api/v1/chat/start` | ✅ |
| 메서드 | POST | POST | ✅ |
| Request | `{scenarioId, characterId, type}` | `{scenario_id, character_id, type}` | ✅ (CamelModel) |
| Response | `{conversationId, firstMessage}` | `{conversation_id, first_message}` | ✅ (CamelModel) |
| Response.firstMessage | `{messageJa, messageKo, hint}` | `{message_ja, message_ko, hint}` | ✅ |

**분석**: 완벽 일치. CamelModel이 자동으로 변환 처리.

---

### ❌ ENDPOINT #5: GET `/chat/{conversationId}` - 응답 필드명 불일치 (CRITICAL)

**모바일**: `/chat/$conversationId` (라인 52)
**백엔드**: `/api/v1/chat/{conversation_id}` (chat_data.py:177)

**상태**: ❌ CRITICAL - 응답 필드명 불일치

| 항목 | 모바일 | 백엔드 | 일치 |
|------|--------|--------|------|
| URL | `/chat/{id}` | `/api/v1/chat/{id}` | ✅ |
| 메서드 | GET | GET | ✅ |
| **응답 필드** | | | |
| - `messages` | 사용 | ✅ `messages` | ✅ |
| - `scenario` | **사용** | **없음** | ❌ |
| - `endedAt` | **사용** | ✅ `endedAt` | ✅ |
| - `feedbackSummary` | **사용** | ✅ `feedbackSummary` | ✅ |

**문제: `scenario` 필드 부재**

모바일 코드 (chat_repository.dart:161-174):
```dart
scenario: json['scenario'] != null
    ? ScenarioModel.fromJson(json['scenario'] as Map<String, dynamic>)
    : null,
```

백엔드 코드 (chat_data.py:177-195):
```python
return {
    "id": str(conv.id),
    "messages": conv.messages,
    "feedbackSummary": conv.feedback_summary,
    "messageCount": conv.message_count,
    "type": conv.type.value,
    "createdAt": conv.created_at.isoformat(),
    "endedAt": conv.ended_at.isoformat() if conv.ended_at else None,
}
```

**백엔드에서 `scenario` 필드를 반환하지 않음!**

**영향**:
- 모바일이 대화 상세 보기에서 `scenario` 정보를 표시하려 하지만 `null`로 처리됨
- 사용자가 어떤 시나리오에서의 대화인지 알 수 없음

**심각도**: 🔴 **CRITICAL**

---

### ✅ ENDPOINT #6: POST `/chat/message` - 완벽 일치

**모바일**: `/chat/message` (라인 61)
**백엔드**: `/api/v1/chat/message` (chat.py:113)

**상태**: ✅ 일치

| 항목 | 모바일 | 백엔드 | 일치 |
|------|--------|--------|------|
| URL | `/chat/message` | `/api/v1/chat/message` | ✅ |
| 메서드 | POST | POST | ✅ |
| Request | `{conversationId, message}` | `{conversation_id, message}` | ✅ (CamelModel) |
| Response | `{messageJa, messageKo, feedback, hint, newVocabulary}` | `{message_ja, ...}` | ✅ |

**분석**: 완벽 일치. CamelModel이 자동으로 변환 처리.

---

### ❌ ENDPOINT #7: POST `/chat/end` - 응답 필드 부재 (CRITICAL)

**모바일**: `/chat/end` (라인 69)
**백엔드**: `/api/v1/chat/end` (chat.py:163)

**상태**: ❌ CRITICAL - 응답 필드 불일치

| 항목 | 모바일 | 백엔드 | 일치 |
|------|--------|--------|------|
| URL | `/chat/end` | `/api/v1/chat/end` | ✅ |
| 메서드 | POST | POST | ✅ |
| Request | `{conversationId}` | `{conversation_id}` | ✅ |
| **응답 필드** | | | |
| - `success` | ✅ 사용 | ✅ | ✅ |
| - `feedbackSummary` | ✅ 사용 | ✅ | ✅ |
| - `xpEarned` | **❌ 미사용** | 💲 반환 | ⚠️ |
| - `events` | **❌ 미사용** | 💲 반환 | ⚠️ |

모바일 코드 (chat_repository.dart:187-195):
```dart
factory EndConversationResponse.fromJson(Map<String, dynamic> json) {
  return EndConversationResponse(
    success: json['success'] as bool? ?? false,
    feedbackSummary: json['feedbackSummary'] != null
        ? FeedbackSummary.fromJson(json['feedbackSummary'] as Map<String, dynamic>)
        : null,
  );
}
```

백엔드 코드 (chat.py:243-248):
```python
return ChatEndResponse(
    success=True,
    feedback_summary=feedback,
    xp_earned=xp,
    events=events,
)
```

**문제**: 모바일이 `xpEarned`와 `events`를 파싱하지 않음

**영향**:
- 백엔드에서 획득한 XP와 업적 정보가 모바일에 전달되지 않음
- 사용자가 획득한 경험치와 달성한 업적을 볼 수 없음
- **게임화 시스템 완전 실패**

**심각도**: 🔴 **CRITICAL**

---

### ❌ ENDPOINT #8: GET `/chat/characters` - 응답 구조 불일치 (HIGH)

**모바일**: `/chat/characters` (라인 80)
**백엔드**: `/api/v1/chat/characters` (chat_data.py:93)

**상태**: ❌ HIGH - 응답 구조 불일치

| 항목 | 모바일 | 백엔드 | 일치 |
|------|--------|--------|------|
| URL | `/chat/characters` | `/api/v1/chat/characters` | ✅ |
| 메서드 | GET | GET | ✅ |
| **응답 구조** | | | |
| 모바일 기대 | `{characters: [...]}` | **직접 배열 반환** | ❌ |
| 백엔드 실제 | - | `[{...}, {...}]` | ❌ |

모바일 코드 (chat_repository.dart:78-85):
```dart
Future<List<CharacterListItem>> fetchCharacters() async {
  final response = await _dio.get<Map<String, dynamic>>('/chat/characters');
  final list = response.data!['characters'] as List<dynamic>? ?? [];
  return list...
}
```

**모바일은 응답이 `{characters: [...]}` 형식일 것으로 기대**

백엔드 코드 (chat_data.py:104-126):
```python
return [  # 직접 배열 반환!
    {
        "id": str(c.id),
        "name": c.name,
        ...
    }
    for c in characters
]
```

**백엔드는 배열을 직접 반환!**

**에러 발생 지점**:
```dart
final list = response.data!['characters'] as List<dynamic>? ?? [];
```

- `response.data`가 배열이므로 `['characters']`는 `null`
- 기본값 `[]`로 설정되어 빈 리스트 반환
- UI에 캐릭터가 표시되지 않음

**영향**: 캐릭터 선택 UI가 비어 있음

**심각도**: 🟠 **HIGH**

---

### ❌ ENDPOINT #9: GET `/chat/characters/stats` - 응답 필드명 불일치 (CRITICAL)

**모바일**: `/chat/characters/stats` (라인 89)
**백엔드**: `/api/v1/chat/characters/stats` (chat_data.py:129)

**상태**: ❌ CRITICAL - 응답 필드명 불일치

| 항목 | 모바일 | 백엔드 | 일치 |
|------|--------|--------|------|
| URL | `/chat/characters/stats` | `/api/v1/chat/characters/stats` | ✅ |
| 메서드 | GET | GET | ✅ |
| 응답 필드 | `['characterStats']` | `['stats']` | ❌ |

모바일 코드 (chat_repository.dart:87-92):
```dart
Future<Map<String, int>> fetchCharacterStats() async {
  final response = await _dio.get<Map<String, dynamic>>('/chat/characters/stats');
  final raw = response.data!['characterStats'] as Map<String, dynamic>? ?? {};
  return raw.map((k, v) => MapEntry(k, v as int? ?? 0));
}
```

**모바일은 `characterStats` 필드를 기대**

백엔드 코드 (chat_data.py:139-140):
```python
stats = {str(row[0]): row[1] for row in result.all()}
return {"stats": stats}
```

**백엔드는 `stats` 필드를 반환!**

**에러 발생**:
```dart
response.data!['characterStats']  // null
```

기본값이 `{}`로 설정되므로 항상 빈 딕셔너리 반환

**영향**: 캐릭터별 사용 횟수 통계가 표시되지 않음

**심각도**: 🔴 **CRITICAL**

---

### ❌ ENDPOINT #10: GET `/chat/characters/favorites` - 응답 필드명 불일치 (CRITICAL)

**모바일**: `/chat/characters/favorites` (라인 96)
**백엔드**: `/api/v1/chat/characters/favorites` (chat_data.py:143)

**상태**: ❌ CRITICAL - 응답 필드명 불일치

| 항목 | 모바일 | 백엔드 | 일치 |
|------|--------|--------|------|
| URL | `/chat/characters/favorites` | `/api/v1/chat/characters/favorites` | ✅ |
| 메서드 | GET | GET | ✅ |
| 응답 필드 | `['favoriteIds']` | `['favorites']` | ❌ |

모바일 코드 (chat_repository.dart:94-99):
```dart
Future<Set<String>> fetchCharacterFavorites() async {
  final response = await _dio.get<Map<String, dynamic>>('/chat/characters/favorites');
  final list = response.data!['favoriteIds'] as List<dynamic>? ?? [];
  return list.map((e) => e as String).toSet();
}
```

**모바일은 `favoriteIds` 필드를 기대**

백엔드 코드 (chat_data.py:148-149):
```python
result = await db.execute(select(UserFavoriteCharacter.character_id).where(UserFavoriteCharacter.user_id == user.id))
return {"favorites": [str(cid) for cid in result.scalars().all()]}
```

**백엔드는 `favorites` 필드를 반환!**

**영향**: 즐겨찾기한 캐릭터 목록이 로드되지 않음

**심각도**: 🔴 **CRITICAL**

---

### ✅ ENDPOINT #11: POST `/chat/characters/favorites` - 완벽 일치

**모바일**: `/chat/characters/favorites` (라인 102)
**백엔드**: `/api/v1/chat/characters/favorites` (chat_data.py:152)

**상태**: ✅ 일치

| 항목 | 모바일 | 백엔드 | 일치 |
|------|--------|--------|------|
| URL | `/chat/characters/favorites` | `/api/v1/chat/characters/favorites` | ✅ |
| 메서드 | POST | POST | ✅ |
| Request | `{characterId}` | `{character_id}` | ✅ |
| Response | `['favorited']` | `{favorited}` | ✅ |

**분석**: 완벽 일치.

---

### ❌ ENDPOINT #12: POST `/chat/live-feedback` - 요청 필드명 불일치 (HIGH)

**모바일**: `/chat/live-feedback` (라인 117)
**백엔드**: `/api/v1/chat/live-feedback` (chat.py:324)

**상태**: ❌ HIGH - 요청/응답 필드명 불일치

| 항목 | 모바일 | 백엔드 | 일치 |
|------|--------|--------|------|
| URL | `/chat/live-feedback` | `/api/v1/chat/live-feedback` | ✅ |
| 메서드 | POST | POST | ✅ |
| **Request 필드** | | | |
| - `transcript` | ❌ **보냄** | ❌ **미사용** | ❌ |
| - `durationSeconds` | ✅ 보냄 | ⚠️ `duration` | ⚠️ |
| - `scenarioId` | ✅ 보냄 | ❌ **미사용** | ⚠️ |
| - `characterId` | ✅ 보냄 | ❌ **미사용** | ⚠️ |
| **Response 필드** | | | |
| - `conversationId` | ✅ 사용 | ✅ (snake_case) | ✅ |
| - `feedbackSummary` | ✅ 사용 | ✅ | ✅ |

모바일 코드 (chat_repository.dart:111-127):
```dart
Future<LiveFeedbackResponse> sendLiveFeedback({
  required List<Map<String, String>> transcript,
  required int durationSeconds,
  String? scenarioId,
  String? characterId,
}) async {
  final response = await _dio.post<Map<String, dynamic>>(
    '/chat/live-feedback',
    data: {
      'transcript': transcript,
      'durationSeconds': durationSeconds,
      if (scenarioId != null) 'scenarioId': scenarioId,
      if (characterId != null) 'characterId': characterId,
    },
  );
  return LiveFeedbackResponse.fromJson(response.data!);
}
```

백엔드 코드 (chat.py:324-341):
```python
@router.post("/live-feedback")
async def submit_live_feedback(
    body: LiveFeedbackRequest,
    ...
):
    result = await db.execute(select(Conversation).where(Conversation.id == body.conversation_id, ...))
    conversation = result.scalar_one_or_none()
    ...
    transcript = conversation.messages or []
    feedback = await generate_live_feedback(
        [{"role": m.get("role", "user"), "text": m.get("content", "")} for m in transcript if m.get("role") != "system"]
    )
```

**문제들**:

1. **`transcript` 필드**: 모바일이 보내지만 백엔드는 사용하지 않음
   - 백엔드는 `conversation.messages`에서 이미 저장된 메시지를 사용
   - 모바일이 전송하는 `transcript` 무시됨

2. **`durationSeconds` vs `duration`**: 필드명 불일치
   - 백엔드 스키마 (chat.py:78-80):
     ```python
     class LiveFeedbackRequest(CamelModel):
         conversation_id: UUID
         duration: int
     ```
   - CamelModel이 `duration`을 기대하는데 모바일은 `durationSeconds` 전송
   - **Pydantic 검증 실패 가능성**

3. **`scenarioId`, `characterId` 미사용**:
   - 모바일이 전송하지만 백엔드는 사용하지 않음
   - 선택사항이므로 에러 안 날 수 있지만 정보 손실

4. **응답 추가 필드**:
   - 백엔드는 `xpEarned`, `events` 포함하여 반환 (chat.py:397-403)
   - 모바일은 파싱하지 않음 (라인 205-214)

**영향**:
- `durationSeconds` 필드명 불일치로 400 Bad Request 에러 가능성 **높음**
- 음성 통화 후 피드백 제출 실패

**심각도**: 🟠 **HIGH** (필드명 불일치) + 🔴 **CRITICAL** (미사용 응답 필드)

---

## 필드 매핑 상세 분석

### CamelModel 자동 변환 규칙

백엔드는 `app.schemas.common.CamelModel`을 사용하여 snake_case ↔ camelCase 자동 변환:

```python
def to_camel(s: str) -> str:
    parts = s.split("_")
    return parts[0] + "".join(p.capitalize() for p in parts[1:])
```

예:
- `scenario_id` → `scenarioId`
- `conversation_id` → `conversationId`
- `message_ja` → `messageJa`

**⚠️ 주의**: 수동 딕셔너리 반환 (dict 사용)은 변환 안 됨!

---

### 수동 딕셔너리 반환의 위험성

chat_data.py에서 여러 엔드포인트가 수동 딕셔너리를 반환:

```python
# ❌ snake_case로 반환 (모바일과 불일치)
return {"stats": stats}  # 라인 140
return {"favorites": [str(cid) for cid in result.scalars().all()]}  # 라인 149
return [...]  # 직접 배열 반환 (라인 104-126)
```

반면 CamelModel을 사용하는 엔드포인트는 자동 변환:

```python
# ✅ CamelModel 사용 → camelCase로 자동 변환
return ChatStartResponse(
    conversation_id=conversation.id,  # → conversationId
    first_message=ChatMessageSchema(...)  # → firstMessage
)
```

---

## 권장 수정 사항

### CRITICAL 우선순위 (즉시 수정)

#### 1️⃣ Chat History: `type` 필드 추가
**파일**: `/apps/api/app/routers/chat_data.py` (라인 68-87)

**현재**:
```python
history.append({
    "id": str(c.id),
    "scenarioTitle": scenario.title if scenario else None,
    ...
    "messageCount": c.message_count,
    "overallScore": feedback.get("overallScore") if isinstance(feedback, dict) else None,
    "createdAt": c.created_at.isoformat(),
    "endedAt": c.ended_at.isoformat() if c.ended_at else None,
})
```

**수정**:
```python
history.append({
    "id": str(c.id),
    "type": c.type.value,  # ← 추가
    "scenarioTitle": scenario.title if scenario else None,
    ...
})
```

---

#### 2️⃣ Get Conversation: `scenario` 필드 추가
**파일**: `/apps/api/app/routers/chat_data.py` (라인 177-195)

**현재**:
```python
return {
    "id": str(conv.id),
    "messages": conv.messages,
    "feedbackSummary": conv.feedback_summary,
    "messageCount": conv.message_count,
    "type": conv.type.value,
    "createdAt": conv.created_at.isoformat(),
    "endedAt": conv.ended_at.isoformat() if conv.ended_at else None,
}
```

**수정**:
```python
scenario = await db.get(ConversationScenario, conv.scenario_id) if conv.scenario_id else None

return {
    "id": str(conv.id),
    "messages": conv.messages,
    "scenario": {  # ← 추가
        "id": str(scenario.id),
        "title": scenario.title,
        "titleJa": scenario.title_ja,
        "description": scenario.description,
        "category": scenario.category.value,
        "difficulty": scenario.difficulty.value,
        "estimatedMinutes": scenario.estimated_minutes,
        "keyExpressions": scenario.key_expressions,
        "situation": scenario.situation,
        "yourRole": scenario.your_role,
        "aiRole": scenario.ai_role,
    } if scenario else None,
    "feedbackSummary": conv.feedback_summary,
    ...
}
```

---

#### 3️⃣ End Chat: `xpEarned`, `events` 응답 추가 (모바일 파싱)
**파일**: `/apps/mobile/lib/features/chat/data/chat_repository.dart` (라인 187-195)

**현재**:
```dart
factory EndConversationResponse.fromJson(Map<String, dynamic> json) {
  return EndConversationResponse(
    success: json['success'] as bool? ?? false,
    feedbackSummary: json['feedbackSummary'] != null
        ? FeedbackSummary.fromJson(json['feedbackSummary'] as Map<String, dynamic>)
        : null,
  );
}
```

**수정**:
```dart
// 먼저 EndConversationResponse 클래스 확장
class EndConversationResponse {
  final bool success;
  final FeedbackSummary? feedbackSummary;
  final int xpEarned;  // ← 추가
  final List<dynamic> events;  // ← 추가

  const EndConversationResponse({
    required this.success,
    this.feedbackSummary,
    required this.xpEarned,  // ← 추가
    required this.events,  // ← 추가
  });

  factory EndConversationResponse.fromJson(Map<String, dynamic> json) {
    return EndConversationResponse(
      success: json['success'] as bool? ?? false,
      feedbackSummary: json['feedbackSummary'] != null
          ? FeedbackSummary.fromJson(json['feedbackSummary'] as Map<String, dynamic>)
          : null,
      xpEarned: json['xpEarned'] as int? ?? 0,  // ← 추가
      events: json['events'] as List<dynamic>? ?? [],  // ← 추가
    );
  }
}
```

---

#### 4️⃣ Get Characters: 응답 구조 수정 (래퍼 객체 추가)
**파일**: `/apps/api/app/routers/chat_data.py` (라인 93-126)

**현재**:
```python
return [
    {
        "id": str(c.id),
        ...
    }
    for c in characters
]
```

**수정**:
```python
return {
    "characters": [
        {
            "id": str(c.id),
            ...
        }
        for c in characters
    ]
}
```

---

#### 5️⃣ Get Character Stats: 필드명 수정
**파일**: `/apps/api/app/routers/chat_data.py` (라인 129-140)

**현재**:
```python
return {"stats": stats}
```

**수정**:
```python
return {"characterStats": stats}
```

---

#### 6️⃣ Get Character Favorites: 필드명 수정
**파일**: `/apps/api/app/routers/chat_data.py` (라인 143-149)

**현재**:
```python
return {"favorites": [str(cid) for cid in result.scalars().all()]}
```

**수정**:
```python
return {"favoriteIds": [str(cid) for cid in result.scalars().all()]}
```

---

#### 7️⃣ Live Feedback: 요청 필드명 수정 (`duration` → `durationSeconds`)
**파일**: `/apps/api/app/schemas/chat.py` (라인 78-80)

**현재**:
```python
class LiveFeedbackRequest(CamelModel):
    conversation_id: UUID
    duration: int
```

**수정**:
```python
class LiveFeedbackRequest(CamelModel):
    conversation_id: UUID
    duration_seconds: int  # ← snake_case로 정의하면 CamelModel이 durationSeconds 수락
    transcript: list[dict[str, str]] | None = None  # ← 추가 (지금은 무시되지만 향후 활용)
    scenario_id: UUID | None = None  # ← 추가
    character_id: UUID | None = None  # ← 추가
```

---

#### 8️⃣ Live Feedback: `xpEarned`, `events` 응답 추가 (모바일 파싱)
**파일**: `/apps/mobile/lib/features/chat/data/models/feedback_model.dart`

LiveFeedbackResponse 클래스 확장:

```dart
class LiveFeedbackResponse {
  final String conversationId;
  final FeedbackSummary? feedbackSummary;
  final int xpEarned;  // ← 추가
  final List<dynamic> events;  // ← 추가

  const LiveFeedbackResponse({
    required this.conversationId,
    this.feedbackSummary,
    required this.xpEarned,  // ← 추가
    required this.events,  // ← 추가
  });

  factory LiveFeedbackResponse.fromJson(Map<String, dynamic> json) {
    return LiveFeedbackResponse(
      conversationId: json['conversationId'] as String? ?? '',
      feedbackSummary: json['feedbackSummary'] != null
          ? FeedbackSummary.fromJson(json['feedbackSummary'] as Map<String, dynamic>)
          : null,
      xpEarned: json['xpEarned'] as int? ?? 0,  // ← 추가
      events: json['events'] as List<dynamic>? ?? [],  // ← 추가
    );
  }
}
```

---

### HIGH 우선순위 (다음 배포)

#### 1️⃣ Fetch Scenarios: `category` 필터 구현
**파일**: `/apps/api/app/routers/chat_data.py` (라인 23-45)

**현재**:
```python
result = await db.execute(
    select(ConversationScenario).where(ConversationScenario.is_active.is_(True)).order_by(ConversationScenario.order)
)
```

**수정**:
```python
@router.get("/scenarios")
async def get_scenarios(
    category: str | None = None,  # ← 추가
    db: AsyncSession = Depends(get_db)
):
    query = select(ConversationScenario).where(ConversationScenario.is_active.is_(True))
    if category:  # ← 필터 추가
        query = query.where(ConversationScenario.category == ScenarioCategory(category))
    query = query.order_by(ConversationScenario.order)

    result = await db.execute(query)
    scenarios = result.scalars().all()
    return [...]
```

---

#### 2️⃣ Chat History: `overallScore` 타입 통일
**파일**: `/apps/api/app/routers/chat_data.py` (라인 83)

모바일은 `int`로 기대하는데 백엔드에서 float 반환할 수 있음:

```python
# 현재
"overallScore": feedback.get("overallScore") if isinstance(feedback, dict) else None,

# 수정
"overallScore": int(feedback.get("overallScore", 0)) if isinstance(feedback, dict) else None,
```

---

## 영향도 요약

### 기능별 영향도

| 기능 | 현재 상태 | 심각도 | 영향받는 사용자 |
|------|---------|--------|----------------|
| 대화 시작 | ✅ 정상 | - | 0% |
| 메시지 전송 | ✅ 정상 | - | 0% |
| 대화 종료 | ❌ XP/업적 미표시 | CRITICAL | 100% |
| 대화 이력 조회 | ⚠️ 타입 정보 손실 | CRITICAL | 100% |
| 대화 상세 보기 | ❌ 시나리오 정보 표시 안 됨 | CRITICAL | 100% |
| 캐릭터 선택 | ❌ 빈 화면 | HIGH | 100% |
| 캐릭터 통계 | ❌ 데이터 미표시 | CRITICAL | 100% |
| 즐겨찾기 | ❌ 목록 로드 실패 | CRITICAL | 100% |
| 음성 대화 | ❌ 피드백 제출 실패 | HIGH | 100% (음성 사용 시) |

---

## 검증 체크리스트

수정 후 다음 사항을 검증하세요:

### 백엔드 수정
- [ ] `chat_data.py` 모든 수동 dict 반환을 확인하고 필드명 통일
- [ ] `/chat/history` 응답에 `type` 필드 추가 확인
- [ ] `/chat/{id}` 응답에 `scenario` 필드 추가 확인
- [ ] `/chat/characters` 응답을 `{characters: [...]}` 래핑 확인
- [ ] `/chat/characters/stats` 응답 필드를 `characterStats`로 수정 확인
- [ ] `/chat/characters/favorites` 응답 필드를 `favoriteIds`로 수정 확인
- [ ] `LiveFeedbackRequest` 스키마 업데이트 확인

### 모바일 수정
- [ ] `EndConversationResponse` 클래스에 `xpEarned`, `events` 필드 추가
- [ ] `LiveFeedbackResponse` 클래스에 `xpEarned`, `events` 필드 추가
- [ ] 모든 API 응답 파싱 테스트

### 통합 테스트
- [ ] Postman/curl로 각 엔드포인트 응답 형식 검증
- [ ] 모바일 앱에서 모든 Chat 기능 테스트
- [ ] 게임화 (XP, 업적) 정상 작동 확인

---

## 결론

**총 9개의 불일치** 발견:

- 🔴 **CRITICAL**: 6개 (즉시 수정 필요)
- 🟠 **HIGH**: 3개 (다음 배포 전 수정)

**예상 수정 시간**: 2-3시간
**테스트 시간**: 1-2시간

**권장 순서**:
1. CRITICAL 이슈 수정 (chat.py + chat_data.py + 모바일 모델)
2. 백엔드 통합 테스트
3. 모바일 빌드 및 E2E 테스트
4. HIGH 이슈 수정 및 재테스트

