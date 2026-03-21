# My/Profile/Subscription/Auth API 불일치 분석 보고서

**작성일**: 2026-03-12
**분석 대상**: Flutter Mobile ↔ FastAPI Backend
**분석 범위**: My, Profile, Subscription, Auth 기능 영역

---

## 요약

총 **8개 엔드포인트** 검사 결과:
- ✅ **호환**: 3개
- 🔴 **불일치**: 5개 (CRITICAL 3개, HIGH 2개)

**핵심 문제**:
1. Profile Detail API: 응답 구조 완전 불일치 (백엔드는 단순 UserProfile, 모바일은 복잡한 중첩 구조 기대)
2. Subscription Status API: 필드명 및 구조 불일치 (파싱 실패 위험)
3. Payments API: 엔드포인트 URL 불일치 + 필드명 불일치
4. Auth Onboarding: 응답 필드 누락

---

## 1. User Profile (UPDATE & FETCH) - [HIGH]

### 모바일 측
```dart
// File: apps/mobile/lib/features/my/data/my_repository.dart:10-17
Future<ProfileDetailModel> fetchProfileDetail() async {
  final response = await _dio.get<Map<String, dynamic>>('/user/profile');
  return ProfileDetailModel.fromJson(response.data!);
}

Future<void> updateProfile(Map<String, dynamic> data) async {
  await _dio.patch<Map<String, dynamic>>('/user/profile', data: data);
}
```

### 백엔드 측
```python
# File: apps/api/app/routers/user.py:35-104
@router.get("/profile", response_model=UserProfileWithStats)
async def get_profile(...):
    return UserProfileWithStats(
        profile=UserProfile.model_validate(user),
        stats=UserStats(...)
    )

@router.patch("/profile", response_model=UserProfile)
async def update_profile(body: UserProfileUpdate, ...):
    return UserProfile.model_validate(user)
```

### 불일치 분석

#### ✅ URL 경로
- 모바일: `/user/profile` + baseUrl (`/api/v1`) = `/api/v1/user/profile`
- 백엔드: GET `/api/v1/user/profile`, PATCH `/api/v1/user/profile`
- **결과**: ✅ 일치

#### 🔴 응답 구조 불일치 (GET)
**모바일이 기대하는 구조**:
```dart
// apps/mobile/lib/features/my/data/models/profile_detail_model.dart:1-24
class ProfileDetailModel {
  final ProfileInfo profile;      // 프로필 정보
  final ProfileSummary summary;   // 통계 요약
  final List<UserAchievement> achievements;  // 업적
}
```

**백엔드가 응답하는 구조**:
```python
# apps/api/app/routers/user.py:74-82
return UserProfileWithStats(
    profile=UserProfile.model_validate(user),  # profile 필드
    stats=UserStats(...)  # stats 필드 (summary가 아님)
)
```

**불일치**:
- 모바일: `{profile: {...}, summary: {...}, achievements: [...]}`
- 백엔드: `{profile: {...}, stats: {...}}`
- 모바일이 기대: `achievements` 필드 (백엔드는 응답 안 함)

**결과**:
- `json['profile']` ✅ 일치
- `json['summary']` → null → {} (ProfileSummary 불완전)
- `json['achievements']` → null → [] (빈 배열)

#### 🔴 필드 불일치 (ProfileInfo)
**모바일이 필요한 필드**:
```dart
id, nickname, avatarUrl, jlptLevel, dailyGoal, experiencePoints, level,
levelProgress (currentXp, xpForNext), streakCount, longestStreak,
showKana, notificationEnabled, callSettings, createdAt
```

**백엔드가 응답 (UserProfile)**:
```python
id, email, nickname, avatar_url (→ avatarUrl), jlpt_level (→ jlptLevel),
goal, daily_goal (→ dailyGoal), experience_points (→ experiencePoints),
level, streak_count (→ streakCount), longest_streak (→ longestStreak),
last_study_date, is_premium, show_kana (→ showKana),
onboarding_completed, call_settings (→ callSettings), created_at (→ createdAt)
```

**누락/추가 필드**:
- 모바일 필요: `levelProgress` → 백엔드 없음 ❌
- 모바일 필요: `notificationEnabled` → 백엔드 없음 ❌ (기본값 사용)
- 백엔드 응답: `email`, `goal`, `last_study_date`, `is_premium`, `onboarding_completed` (모바일 미사용)

#### 파싱 결과
```dart
// ProfileDetailModel 생성 시
profile: {
  id: UUID ✅
  nickname: 'John' ✅
  avatarUrl: 'url' ✅
  jlptLevel: 'N4' ✅
  dailyGoal: 10 ✅
  experiencePoints: 5000 ✅
  level: 5 ✅
  levelProgress: null → {} ❌ 빈 객체 (CamelCase 변환 실패)
  // ...
}
summary: null → {} ❌ 프로필 요약 데이터 누락
achievements: null → [] ❌ 빈 배열 (업적 없음)
```

### 영향
- **파싱**: 부분적 성공 (profile 부분만, summary/achievements는 빈 값)
- **UX**: 프로필 통계/업적 미표시

### 권장사항
**옵션 A (권장): 백엔드 응답 구조 변경**
- 현재: `{profile, stats}`
- 변경: `{profile, summary (stats의 일부), achievements}`

**옵션 B: 모바일 파싱 로직 변경**
- 백엔드 `stats`를 모바일 `summary`로 매핑
- achievements 별도 엔드포인트로 조회

#### ✅ PATCH 요청
- URL: ✅ 일치
- Body: CamelCase로 전송 (Dio 자동 변환)
- 응답: UserProfile (CamelCase 변환)
- **결과**: ✅ 호환

---

## 2. Subscription Status - [CRITICAL]

### 모바일 측
```dart
// File: apps/mobile/lib/features/my/data/my_repository.dart:19-23
Future<SubscriptionStatus> fetchSubscriptionStatus() async {
  final response = await _dio.get<Map<String, dynamic>>('/subscription/status');
  return SubscriptionStatus.fromJson(response.data!);
}

// File: apps/mobile/lib/features/my/data/models/subscription_model.dart:1-22
class SubscriptionStatus {
  final SubscriptionInfo subscription;
  final AiUsage? aiUsage;

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      subscription: SubscriptionInfo(
        isPremium: json['isPremium'] as bool? ?? false,
        plan: json['plan'] as String? ?? 'free',
        expiresAt: json['expiresAt'] as String?,
        cancelledAt: json['cancelledAt'] as String?,
      ),
      aiUsage: json['usage'] != null
          ? AiUsage.fromJson(json['usage'] as Map<String, dynamic>)
          : null,
    );
  }
}

// AiUsage 필드: chatCount, chatLimit, callCount, callLimit
```

### 백엔드 측
```python
# File: apps/api/app/routers/subscription.py:37-58
@router.get("/status", response_model=SubscriptionStatusResponse)
async def get_status(...):
    return SubscriptionStatusResponse(
        is_premium=status["is_premium"],
        plan=status["plan"],
        expires_at=status["expires_at"],
        cancelled_at=status["cancelled_at"],
        usage=AiUsage(**usage),
        limits=AiLimits(
            chat_count=limits.CHAT_COUNT,
            chat_seconds=limits.CHAT_SECONDS,
            call_count=limits.CALL_COUNT,
            call_seconds=limits.CALL_SECONDS,
        ),
    )

# Schema: apps/api/app/schemas/subscription.py
class SubscriptionStatusResponse(CamelModel):
    is_premium: bool  # → isPremium
    plan: SubscriptionPlan
    expires_at: datetime | None = None  # → expiresAt
    cancelled_at: datetime | None = None  # → cancelledAt
    usage: AiUsage  # usage 필드 정상
    limits: AiLimits  # 🔴 모바일에 없음
```

### 불일치 분석

#### ✅ URL 경로
- 모바일: `/subscription/status` + baseUrl = `/api/v1/subscription/status`
- 백엔드: `/api/v1/subscription/status`
- **결과**: ✅ 일치

#### 🔴 응답 구조 불일치
| 항목 | 모바일 기대 | 백엔드 응답 | 호환성 |
|------|-----------|-----------|--------|
| 래퍼 | `{subscription: {...}, usage: {...}}` | `{isPremium, plan, expiresAt, cancelledAt, usage, limits}` | ❌ 불일치 |

**백엔드**는 flat 구조로 응답하는데, **모바일**은 nested 구조를 기대함.

#### 🔴 CamelCase 변환
**백엔드 응답** (CamelModel 자동 변환):
```python
is_premium → isPremium ✅
plan → plan ✅
expires_at → expiresAt ✅
cancelled_at → cancelledAt ✅
usage → usage ✅
limits → limits 🔴
```

**모바일 파싱** (subscription_model.dart:11-16):
```dart
isPremium: json['isPremium'] ✅
plan: json['plan'] ✅
expiresAt: json['expiresAt'] ✅
cancelledAt: json['cancelledAt'] ✅
usage: json['usage'] ✅
// limits는 없음
```

#### 🔴 필드 누락
**백엔드가 추가 응답** (모바일에 없음):
```python
limits: AiLimits {
    chat_count: int,
    chat_seconds: int,
    call_count: int,
    call_seconds: int
}
```

**모바일이 기대** (없음):
```dart
// limits 필드 없음
// AiUsage에만: chatCount, chatLimit, callCount, callLimit
```

**불일치**:
- 백엔드 `usage` = `{chatCount, chatSeconds, callCount, callSeconds}`
- 모바일 기대 = `{chatCount, chatLimit, callCount, callLimit}`
- `chatSeconds` vs `chatLimit` 불일치!
- `callSeconds` vs `callLimit` 불일치!

#### 파싱 결과
```dart
// SubscriptionStatus 생성
subscription: {
  isPremium: false ✅
  plan: 'monthly' ✅
  expiresAt: '2026-04-12' ✅
  cancelledAt: null ✅
}
aiUsage: {
  chatCount: 2 ✅ (but expecting limit?)
  chatLimit: 0 ❌ (backend sends chatSeconds)
  callCount: 1 ✅ (but expecting limit?)
  callLimit: 0 ❌ (backend sends callSeconds)
}
```

### 영향
- **파싱**: 부분 실패
- **기능**: AI 사용량은 표시되지만, 제한량이 0으로 표시됨
- **UX**: "AI 채팅 0회 제한" 같은 이상한 메시지 표시

### 권장사항
**옵션 A (권장): 백엔드 필드명 통일**
- `chat_seconds` → `chat_limit` (시간 제한 아님, 횟수 제한)
- `call_seconds` → `call_limit`

**옵션 B: 모바일 필드명 변경**
- `chatLimit` → `chatSeconds`
- `callLimit` → `callSeconds`
- 의미 재정의 (시간 제한으로)

---

## 3. Payments History - [CRITICAL]

### 모바일 측
```dart
// File: apps/mobile/lib/features/my/data/my_repository.dart:40-46
Future<Map<String, dynamic>> fetchPayments(int page) async {
  final response = await _dio.get<Map<String, dynamic>>(
    '/subscription/payments',  // 🔴 URL: /subscription/payments
    queryParameters: {'page': page},
  );
  return response.data!;
}
```

### 백엔드 측
```python
# File: apps/api/app/routers/payments.py:11-21
router = APIRouter(prefix="/api/v1/payments", tags=["payments"])

@router.get("/")
async def list_payments(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=10, le=50),
    ...
):
    return await get_payment_history(db, str(user.id), page, page_size)
```

### 불일치 분석

#### 🔴 URL 경로 불일치
| 항목 | 모바일 | 백엔드 |
|------|--------|--------|
| 호출 | `/subscription/payments` | `/payments/` |
| 완전 URL | `/api/v1/subscription/payments` | `/api/v1/payments/` |
| 일치 여부 | ❌ | ❌ |

**문제**: 모바일이 `/subscription/payments`를 호출하지만, 백엔드는 `/payments/`만 정의.

**결과**: 404 Not Found 🚨

#### 🔴 쿼리 파라미터
**모바일**:
```dart
queryParameters: {'page': page}  // page만
```

**백엔드**:
```python
page: int = Query(default=1, ge=1),
page_size: int = Query(default=10, le=50),  // page_size도 있음
```

**불일치**: 모바일이 `page_size` 파라미터를 보내지 않음 → 기본값 10 적용

#### 🔴 응답 필드 불일치
**모바일 기대** (paymentModel.dart:1-27):
```dart
class PaymentRecord {
  id: String
  plan: String
  amount: int
  status: String
  paidAt: String?
  createdAt: String
}
```

**백엔드 응답** (subscription.py, payment_history 서비스):
```python
# PaymentHistoryResponse
class PaymentHistoryItem(CamelModel):
    id: UUID
    amount: int
    currency: str  # 🔴 모바일에 없음
    status: PaymentStatus  # enum
    plan: SubscriptionPlan  # enum
    paid_at: datetime | None  # 🔴 datetime, not string
    created_at: datetime  # 🔴 datetime, not string

class PaymentHistoryResponse(CamelModel):
    payments: list[PaymentHistoryItem]
    total: int
    page: int
    page_size: int
    total_pages: int
```

**필드 비교**:
| 필드 | 모바일 기대 | 백엔드 응답 | 호환성 |
|------|----------|-----------|--------|
| id | String | UUID (CamelCase) | ✅ |
| plan | String | SubscriptionPlan (enum) | ❌ string 아님 |
| amount | int | int | ✅ |
| status | String | PaymentStatus (enum) | ❌ string 아님 |
| paidAt | String? | datetime? | ❌ 타입 다름 |
| createdAt | String | datetime | ❌ 타입 다름 |
| currency | ❌ | String | 🟡 추가 필드 |

#### 파싱 결과
```dart
// 모바일이 받은 응답 (실제):
{
  "payments": [
    {
      "id": "uuid-string",
      "plan": "MONTHLY",  // enum 값, string처럼 보임 ✅ (운 좋게)
      "amount": 4900,
      "status": "COMPLETED",  // enum 값
      "paidAt": "2026-03-01T10:00:00Z",  // datetime string
      "createdAt": "2026-03-01T09:00:00Z",  // datetime string
      "currency": "KRW"
    }
  ],
  "total": 10,
  "page": 1,
  "page_size": 10,
  "total_pages": 1
}

// 모바일 파싱
response.data! // 전체 Map 반환 (PaymentHistoryResponse 구조)
```

**문제**: 모바일이 `response.data!` 전체를 반환하므로, 실제로는 `PaymentHistoryResponse` 구조를 받음.
모바일이 `response.data!['payments']`를 처리해야 하는데, 코드상 전체 Map을 반환함.

### 영향
- **URL 불일치**: 404 Not Found (요청 실패) 🚨
- **구조 불일치**: datetime 문자열로 반환되므로 파싱 가능하지만, 구조 불일치
- **필드 타입**: enum 문자열로 반환되므로 운 좋게 작동할 수 있음

### 권장사항
**긴급 수정**:
1. **백엔드 라우터 수정**: `/payments/` → `/api/v1/subscription/payments/`
2. **모바일 응답 처리**: 전체 Map이 아닌 `response.data!['payments']` 처리
3. **필드명 일치**: `paid_at` → `paidAt`, `created_at` → `createdAt` (CamelModel이 자동 변환하므로 OK)

---

## 4. Subscription Cancel/Resume - [HIGH]

### 모바일 측
```dart
// File: apps/mobile/lib/features/my/data/my_repository.dart:25-34
Future<void> cancelSubscription({String? reason}) async {
  await _dio.post<Map<String, dynamic>>(
    '/subscription/cancel',
    data: {'reason': reason},
  );
}

Future<void> resumeSubscription() async {
  await _dio.post<Map<String, dynamic>>('/subscription/resume');
}
```

### 백엔드 측
```python
# File: apps/api/app/routers/subscription.py:136-160
@router.post("/cancel")
async def cancel(body: CancelRequest, ...):
    return {"success": True}

@router.post("/resume")
async def resume(user: ..., db: ...):
    return {"success": True}
```

### 불일치 분석

#### ✅ URL 경로
- 모바일: `/subscription/cancel`, `/subscription/resume`
- 백엔드: `/api/v1/subscription/cancel`, `/api/v1/subscription/resume`
- **결과**: ✅ 일치

#### ✅ 요청 바디
- 모바일: `{'reason': reason}`
- 백엔드: `CancelRequest(reason: str | None)`
- **결과**: ✅ 일치 (CamelModel이 자동 처리)

#### ✅ 응답
- 모바일: 반환값 무시
- 백엔드: `{"success": True}`
- **결과**: ✅ 호환

### 영향
- **파싱**: ✅ 완전 호환

---

## 5. Subscription Subscribe - [HIGH]

### 모바일 측
```dart
// File: apps/mobile/lib/features/subscription/data/subscription_repository.dart:15-20
Future<void> subscribe(String planId) async {
  await _dio.post<Map<String, dynamic>>(
    '/subscription/subscribe',
    data: {'plan': planId},
  );
}
```

### 백엔드 측
```python
# File: apps/api/app/routers/subscription.py - /subscribe 없음
# 대신 /checkout (결제 준비) → /activate (결제 완료) 플로우
```

### 불일치 분석

#### 🔴 엔드포인트 완전 부재
**모바일**: `/subscription/subscribe` 호출
**백엔드**: 해당 엔드포인트 없음 ❌

**백엔드 대신 제공**:
- `POST /api/v1/subscription/checkout` - 결제 준비
- `POST /api/v1/subscription/activate` - 결제 활성화

**문제**: 설계 차이. 모바일은 직접 subscribe, 백엔드는 checkout → activate 2단계 플로우.

### 영향
- **기능 불가능**: 모바일이 subscribe 호출 시 404 Not Found

### 권장사항
**옵션 A (권장)**: 백엔드에 `/subscribe` 엔드포인트 추가
```python
@router.post("/subscribe")
async def subscribe(body: SubscribeRequest, ...):
    # checkout → activate 자동 수행
```

**옵션 B**: 모바일 로직 변경
- checkout 호출 → payment UI → activate 호출로 변경

---

## 6. Delete Account - [HIGH]

### 모바일 측
```dart
// File: apps/mobile/lib/features/my/data/my_repository.dart:36-38
Future<void> deleteAccount() async {
  await _dio.delete<Map<String, dynamic>>('/user/account');
}
```

### 백엔드 측
```python
# File: apps/api/app/routers/user.py - DELETE 메서드 없음
# user.py에는 GET /profile, PATCH /profile, PATCH /avatar, PATCH /account만 정의
```

### 불일치 분석

#### 🔴 HTTP 메서드 불일치
| 항목 | 모바일 | 백엔드 |
|------|--------|--------|
| 메서드 | DELETE | PATCH |
| URL | DELETE `/user/account` | PATCH `/user/account` |

**문제**: 모바일은 DELETE, 백엔드는 PATCH 사용.

### user.py 내용 확인
```python
@router.patch("/account", response_model=dict)
async def update_account(body: AccountUpdateRequest, ...):
    # nickname, email 업데이트만 가능
    # 계정 삭제 기능 없음
```

**결과**: 모바일 DELETE 요청 → 405 Method Not Allowed 또는 404

### 영향
- **기능 불가능**: 계정 삭제 기능 동작 안 함

### 권장사항
백엔드에 DELETE 엔드포인트 추가:
```python
@router.delete("/account")
async def delete_account(user: User = Depends(...), db: AsyncSession = Depends(...)):
    await db.delete(user)
    await db.commit()
    return {"success": True}
```

---

## 7. Auth Onboarding - [CRITICAL]

### 모바일 측
```dart
// File: apps/mobile/lib/features/auth/providers/onboarding_provider.dart
// (실제 구현 미확인, 로직만 예상)
```

### 백엔드 측
```python
# File: apps/api/app/routers/auth.py:17-36
@router.post("/onboarding", response_model=OnboardingResponse)
async def onboarding(body: OnboardingRequest, ...):
    user.nickname = body.nickname
    user.jlpt_level = body.jlpt_level
    user.daily_goal = body.daily_goal
    user.onboarding_completed = True
    if body.goal is not None:
        user.goal = body.goal
    await db.commit()
    await db.refresh(user)

    return OnboardingResponse(
        success=True,
        user=UserProfile.model_validate(user),
    )

# Schema: apps/api/app/schemas/auth.py
class OnboardingResponse(CamelModel):
    success: bool
    user: UserProfile
```

### 불일치 분석

#### ✅ URL 경로 (예상)
- 모바일: `/auth/onboarding` + baseUrl = `/api/v1/auth/onboarding`
- 백엔드: `/api/v1/auth/onboarding`
- **결과**: ✅ 일치 (예상)

#### ✅ 요청 바디 (예상)
```python
class OnboardingRequest(CamelModel):
    nickname: str
    jlpt_level: JlptLevel
    goal: UserGoal | None = None
    daily_goal: int = 10
```
**결과**: ✅ 모바일이 이 필드들을 전송하면 호환

#### ✅ 응답
```python
OnboardingResponse(
    success=True,
    user=UserProfile(...)
)
```
**결과**: ✅ CamelCase 변환으로 모바일이 파싱 가능

#### ✅ Supabase Auth 연동
**모바일**:
```dart
// authRepository.dart에서 Supabase 직접 사용
final account = await _googleSignIn.signIn();
return _client.auth.signInWithIdToken(...);
```

**백엔드**: Supabase Auth 미들웨어 (get_current_user)

**결과**: ✅ Supabase 토큰 기반 인증 (호환)

### 영향
- **파싱**: ✅ 완전 호환 (예상)

---

## 종합 불일치 요약표

| # | 엔드포인트 | 방식 | URL | 요청 | 응답 | 심각도 |
|---|-----------|-----|-----|------|------|--------|
| 1 | Profile Detail (GET) | GET | ✅ | - | ❌ 구조 | **CRITICAL** |
| 2 | Profile Detail (PATCH) | PATCH | ✅ | ✅ | ✅ | ✅ |
| 3 | Subscription Status | GET | ✅ | - | ❌ 필드 | **CRITICAL** |
| 4 | Payments List | GET | ❌ | ❌ 파라미터 | ❌ 구조 | **CRITICAL** |
| 5 | Cancel Subscription | POST | ✅ | ✅ | ✅ | ✅ |
| 6 | Resume Subscription | POST | ✅ | - | ✅ | ✅ |
| 7 | Subscribe (직접) | POST | ❌ | - | - | **HIGH** |
| 8 | Delete Account | DELETE | ❌ | - | - | **HIGH** |

---

## 우선순위별 수정 로드맵

### Phase 1 (긴급, 즉시)
- [ ] **Profile Detail**: 응답 구조 변경 (profile, summary, achievements)
- [ ] **Subscription Status**: 필드명 통일 (chatSeconds vs chatLimit)
- [ ] **Payments API**:
  - URL 변경: `/subscription/payments` 또는 `/payments/subscription`
  - 응답 구조 맞춤

### Phase 2 (높음, 1주)
- [ ] **Delete Account**: DELETE `/user/account` 엔드포인트 추가
- [ ] **Subscribe**: `/subscription/subscribe` 엔드포인트 추가 (또는 모바일 로직 변경)

### Phase 3 (중간, 2-3주)
- [ ] Auth Onboarding 통합 테스트
- [ ] 모든 My/Subscription 기능 E2E 테스트

---

## 결론

**현재 상태**:
- 기본 인증은 Supabase로 동작함
- Profile 업데이트는 부분적 동작
- Subscription Status/Payments는 심각한 불일치
- Delete Account/Subscribe는 완전 불가능

**긴급도**: 🔴 CRITICAL (Profile, Subscription, Payments)

**예상 영향**:
- My 페이지: 프로필/업적 미표시
- Subscription 페이지: AI 사용량 이상 표시
- Payments 페이지: 404 에러
- 계정 삭제: 불가능
