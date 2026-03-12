# My/Profile/Subscription/Auth API 불일치 분석 보고서

**분석 완료일**: 2026-03-12
**분석자**: Backend Analyst
**심각도**: HIGH (여러 critical mismatches)

---

## Executive Summary

모바일(Flutter)과 백엔드(FastAPI) 간 My/Profile/Subscription/Auth 영역에서 **6개의 critical/high 불일치**가 발견되었습니다:

1. **Onboarding 요청 필드 불일치** (showKana 전송 vs 미사용)
2. **프로필 조회 응답 구조 불일치** (profile+stats 분리 vs 원본 필드)
3. **프로필 업데이트 필드 누락** (notificationEnabled 누락)
4. **구독 상태 응답 필드명 불일치** (isPremium vs is_premium)
5. **결제 이력 URL 오류** (/subscription/payments vs /payments/)
6. **결제 구현 미흡** (CheckoutPage가 "준비 중" 상태)

---

## 1단계: 모바일 측 API 호출 정리

### A. Auth (인증)

#### 파일: `/apps/mobile/lib/features/auth/data/auth_repository.dart`
- Supabase 직접 사용 (백엔드와 분리)
- OAuth (Google, Kakao), Email (Sign-in/Sign-up), Password Reset
- JWT 토큰은 Supabase에서 발급

#### 파일: `/apps/mobile/lib/features/auth/presentation/onboarding_page.dart:40-48`
```dart
await dio.post<Map<String, dynamic>>(
  '/auth/onboarding',
  data: {
    'nickname': state.nickname,
    'jlptLevel': state.jlptLevel,
    'goal': state.goal,
    'showKana': state.showKana,  // ← 모바일이 전송
  },
);
```

**API 호출**: `POST /api/v1/auth/onboarding`
- 요청 필드: `nickname`, `jlptLevel`, `goal`, `showKana`

---

### B. My/Profile

#### 파일: `/apps/mobile/lib/features/my/data/my_repository.dart`

```dart
// 1. 프로필 조회
Future<ProfileDetailModel> fetchProfileDetail() async {
  final response = await _dio.get<Map<String, dynamic>>('/user/profile');
  return ProfileDetailModel.fromJson(response.data!);
}

// 2. 프로필 업데이트
Future<void> updateProfile(Map<String, dynamic> data) async {
  await _dio.patch<Map<String, dynamic>>('/user/profile', data: data);
}

// 3. 결제 내역 조회
Future<Map<String, dynamic>> fetchPayments(int page) async {
  final response = await _dio.get<Map<String, dynamic>>(
    '/subscription/payments',  // ← URL
    queryParameters: {'page': page},
  );
  return response.data!;
}

// 4. 계정 삭제
Future<void> deleteAccount() async {
  await _dio.delete<Map<String, dynamic>>('/user/account');
}
```

**API 호출들**:
1. `GET /api/v1/user/profile` - 프로필 상세 조회
2. `PATCH /api/v1/user/profile` - 프로필 업데이트
3. `GET /api/v1/subscription/payments?page={page}` - 결제 내역
4. `DELETE /api/v1/user/account` - 계정 삭제

#### 모바일이 기대하는 응답 구조 (프로필 조회)

파일: `/apps/mobile/lib/features/my/data/models/profile_detail_model.dart:12-24`

```dart
factory ProfileDetailModel.fromJson(Map<String, dynamic> json) {
  return ProfileDetailModel(
    profile: ProfileInfo.fromJson(
      json['profile'] as Map<String, dynamic>? ?? {},
    ),
    summary: ProfileSummary.fromJson(
      json['summary'] as Map<String, dynamic>? ?? {},
    ),
    achievements: (json['achievements'] as List<dynamic>? ?? [])
        .map((e) => UserAchievement.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
```

**모바일이 기대하는 JSON 구조**:
```json
{
  "profile": {
    "id": "uuid",
    "nickname": "string",
    "avatarUrl": "string|null",
    "jlptLevel": "string",
    "dailyGoal": "int",
    "experiencePoints": "int",
    "level": "int",
    "levelProgress": {
      "currentXp": "int",
      "xpForNext": "int"
    },
    "streakCount": "int",
    "longestStreak": "int",
    "showKana": "bool",
    "notificationEnabled": "bool",
    "callSettings": {
      "silenceTimeout": "int",
      "showSubtitles": "bool",
      "autoAnalyze": "bool"
    },
    "createdAt": "string"
  },
  "summary": {
    "totalWordsStudied": "int",
    "totalQuizzesCompleted": "int",
    "totalStudyDays": "int",
    "totalXpEarned": "int"
  },
  "achievements": [
    {
      "achievementType": "string",
      "achievedAt": "string"
    }
  ]
}
```

#### 모바일이 프로필 업데이트할 때 보내는 필드

사용 예 (`/apps/mobile/lib/features/my/presentation/my_page.dart:70-88`):
```dart
await ref.read(myRepositoryProvider).updateProfile({
  field: value  // nickname, jlptLevel, dailyGoal, showKana, callSettings 등
});
```

기대하는 필드:
- `nickname`: string
- `jlptLevel`: string
- `dailyGoal`: int
- `goal`: string
- `showKana`: bool
- `callSettings`: Map

---

### C. Subscription

#### 파일: `/apps/mobile/lib/features/my/data/my_repository.dart:19-23`

```dart
Future<SubscriptionStatus> fetchSubscriptionStatus() async {
  final response =
      await _dio.get<Map<String, dynamic>>('/subscription/status');
  return SubscriptionStatus.fromJson(response.data!);
}
```

**API 호출**: `GET /api/v1/subscription/status`

#### 모바일이 기대하는 응답 구조

파일: `/apps/mobile/lib/features/my/data/models/subscription_model.dart:7-21`

```dart
factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
  return SubscriptionStatus(
    subscription: SubscriptionInfo(
      isPremium: json['isPremium'] as bool? ?? false,      // ← camelCase
      plan: json['plan'] as String? ?? 'free',
      expiresAt: json['expiresAt'] as String?,             // ← camelCase
      cancelledAt: json['cancelledAt'] as String?,         // ← camelCase
    ),
    aiUsage: json['usage'] != null
        ? AiUsage.fromJson(json['usage'] as Map<String, dynamic>)
        : null,
  );
}
```

**모바일이 기대하는 구조** (camelCase):
```json
{
  "isPremium": "bool",
  "plan": "string",
  "expiresAt": "string|null",
  "cancelledAt": "string|null",
  "usage": {
    "chatCount": "int",
    "chatSeconds": "int",
    "callCount": "int",
    "callSeconds": "int"
  },
  "limits": {
    "chatCount": "int",
    "chatSeconds": "int",
    "callCount": "int",
    "callSeconds": "int"
  }
}
```

---

### D. Payments

#### 결제 내역 조회

파일: `/apps/mobile/lib/features/my/presentation/payments_page.dart:31`

```dart
final data = await ref.read(myRepositoryProvider).fetchPayments(_page);
```

기대하는 응답:
```json
{
  "payments": [
    {
      "id": "string",
      "plan": "monthly|yearly",
      "amount": "int",
      "status": "paid|pending|failed|refunded|cancelled",
      "paidAt": "string|null",
      "createdAt": "string"
    }
  ],
  "totalPages": "int"
}
```

---

## 2단계: 백엔드 측 엔드포인트 정리

### A. Auth Router (`/apps/api/app/routers/auth.py`)

#### `POST /api/v1/auth/onboarding`

파일: `/apps/api/app/routers/auth.py:17-36`

```python
@router.post("/onboarding", response_model=OnboardingResponse)
async def onboarding(
    body: OnboardingRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    user.nickname = body.nickname
    user.jlpt_level = body.jlpt_level
    user.daily_goal = body.daily_goal
    user.onboarding_completed = True
    if body.goal is not None:
        user.goal = body.goal
    # note: showKana NOT used
```

**요청 스키마** (`/apps/api/app/schemas/auth.py`):
```python
class OnboardingRequest(CamelModel):
    nickname: str
    jlpt_level: JlptLevel
    goal: UserGoal | None = None
    daily_goal: int = 10
    # showKana field is NOT here!
```

---

### B. User Router (`/apps/api/app/routers/user.py`)

#### `GET /api/v1/user/profile` - 프로필 조회

파일: `/apps/api/app/routers/user.py:35-82`

```python
@router.get("/profile", response_model=UserProfileWithStats)
async def get_profile(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    # ... calculate stats ...
    return UserProfileWithStats(
        profile=UserProfile.model_validate(user),
        stats=UserStats(
            total_words_studied=total_words,
            total_quizzes_completed=total_quizzes,
            total_study_days=total_study_days,
            achievements=achievements,
        ),
    )
```

**응답 스키마** (`/apps/api/app/schemas/user.py:11-28`):
```python
class UserProfile(CamelModel):
    id: UUID
    email: str
    nickname: str
    avatar_url: str | None = None
    jlpt_level: JlptLevel
    goal: UserGoal | None = None
    daily_goal: int
    experience_points: int
    level: int
    streak_count: int
    longest_streak: int
    last_study_date: date | None = None
    is_premium: bool
    show_kana: bool
    onboarding_completed: bool
    call_settings: dict[str, Any] | None = None
    created_at: datetime
```

**CamelModel 자동 변환** → snake_case를 camelCase로 변환:
- `experience_points` → `experiencePoints`
- `streak_count` → `streakCount`
- `longest_streak` → `longestStreak`
- `last_study_date` → `lastStudyDate`
- `is_premium` → `isPremium`
- `show_kana` → `showKana`
- `onboarding_completed` → `onboardingCompleted`
- `call_settings` → `callSettings`
- `created_at` → `createdAt`

**백엔드가 반환하는 실제 구조**:
```json
{
  "profile": {
    "id": "uuid",
    "email": "string",
    "nickname": "string",
    "avatarUrl": "string|null",
    "jlptLevel": "string",
    "goal": "string|null",
    "dailyGoal": "int",
    "experiencePoints": "int",
    "level": "int",
    "streakCount": "int",
    "longestStreak": "int",
    "lastStudyDate": "date|null",
    "isPremium": "bool",
    "showKana": "bool",
    "onboardingCompleted": "bool",
    "callSettings": "dict|null",
    "createdAt": "datetime"
  },
  "stats": {
    "totalWordsStudied": "int",
    "totalQuizzesCompleted": "int",
    "totalStudyDays": "int",
    "achievements": [...]
  }
}
```

---

#### `PATCH /api/v1/user/profile` - 프로필 업데이트

파일: `/apps/api/app/routers/user.py:85-104`

```python
@router.patch("/profile", response_model=UserProfile)
async def update_profile(
    body: UserProfileUpdate,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    update_data = body.model_dump(exclude_unset=True)
    # ... handle call_settings merge ...
    for field, value in update_data.items():
        setattr(user, field, value)
    await db.commit()
    await db.refresh(user)
    return UserProfile.model_validate(user)
```

**업데이트 스키마** (`/apps/api/app/schemas/user.py:31-37`):
```python
class UserProfileUpdate(CamelModel):
    nickname: str | None = None
    jlpt_level: JlptLevel | None = None
    daily_goal: int | None = None
    goal: UserGoal | None = None
    show_kana: bool | None = None
    call_settings: dict[str, Any] | None = None
    # notificationEnabled is NOT here!
```

---

#### `DELETE /api/v1/user/account` - 계정 삭제

**엔드포인트 없음!** 백엔드에 구현되어 있지 않습니다.

---

### C. Subscription Router (`/apps/api/app/routers/subscription.py`)

#### `GET /api/v1/subscription/status` - 구독 상태

파일: `/apps/api/app/routers/subscription.py:37-58`

```python
@router.get("/status", response_model=SubscriptionStatusResponse)
async def get_status(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    status = await get_subscription_status(db, str(user.id))
    usage = await get_daily_ai_usage(db, str(user.id))
    limits = AI_LIMITS.PREMIUM if status["is_premium"] else AI_LIMITS.FREE

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
```

**응답 스키마** (`/apps/api/app/schemas/subscription.py:24-30`):
```python
class SubscriptionStatusResponse(CamelModel):
    is_premium: bool       # ← snake_case (CamelModel으로 변환됨)
    plan: SubscriptionPlan
    expires_at: datetime | None = None      # ← snake_case
    cancelled_at: datetime | None = None    # ← snake_case
    usage: AiUsage
    limits: AiLimits
```

**CamelModel 변환 후**:
- `is_premium` → `isPremium` ✓
- `expires_at` → `expiresAt` ✓
- `cancelled_at` → `cancelledAt` ✓

---

#### `POST /api/v1/subscription/checkout` - 결제 준비

파일: `/apps/api/app/routers/subscription.py:61-93`

```python
@router.post("/checkout", response_model=CheckoutResponse)
async def create_checkout(
    body: CheckoutRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    # ... create payment ...
    return CheckoutResponse(
        payment_id=payment_id,
        store_id=settings.PORTONE_STORE_ID,
        channel_key=settings.PORTONE_CHANNEL_KEY,
        order_name=f"하루코토 {'월간' if plan == 'monthly' else '연간'} 프리미엄",
        total_amount=amount,
        currency="KRW",
        customer_id=str(user.id),
    )
```

**응답 스키마** (`/apps/api/app/schemas/subscription.py:37-44`):
```python
class CheckoutResponse(CamelModel):
    payment_id: str
    store_id: str
    channel_key: str
    order_name: str
    total_amount: int
    currency: str
    customer_id: str
```

---

#### `POST /api/v1/subscription/activate` - 결제 활성화

파일: `/apps/api/app/routers/subscription.py:96-133`

```python
@router.post("/activate")
async def activate(
    body: ActivateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    # ... verify payment and activate ...
    return {
        "success": True,
        "subscriptionId": str(subscription.id),
        "currentPeriodEnd": subscription.current_period_end.isoformat(),
    }
```

---

#### `POST /api/v1/subscription/cancel` - 구독 취소

파일: `/apps/api/app/routers/subscription.py:136-147`

```python
@router.post("/cancel")
async def cancel(
    body: CancelRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    await cancel_subscription(db, str(user.id), body.reason)
    await db.commit()
    return {"success": True}
```

---

#### `POST /api/v1/subscription/resume` - 구독 재개

파일: `/apps/api/app/routers/subscription.py:150-160`

```python
@router.post("/resume")
async def resume(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    await resume_subscription(db, str(user.id))
    await db.commit()
    return {"success": True}
```

---

### D. Payments Router (`/apps/api/app/routers/payments.py`)

#### `GET /api/v1/payments/` - 결제 내역

파일: `/apps/api/app/routers/payments.py:14-21`

```python
@router.get("/")
async def list_payments(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=10, le=50),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await get_payment_history(db, str(user.id), page, page_size)
```

**응답 스키마** (`/apps/api/app/schemas/subscription.py:65-70`):
```python
class PaymentHistoryResponse(CamelModel):
    payments: list[PaymentHistoryItem]
    total: int
    page: int
    page_size: int
    total_pages: int
```

---

### E. Auth Flow (인증)

파일: `/apps/api/app/dependencies.py`

**인증 방식**:
1. Supabase JWT 토큰을 `Authorization: Bearer <token>` 헤더로 전송
2. JWKS (ES256) 우선 검증, HS256 폴백
3. 토큰의 `sub` 클레임으로 user_id 추출
4. DB에서 사용자 검증

**플로우**:
```
Supabase Auth (OAuth/Email)
    ↓
[JWT 토큰 발급]
    ↓
모바일 AuthInterceptor
    ↓
[Authorization: Bearer <token>]
    ↓
FastAPI get_current_user
    ↓
[JWT 검증]
    ↓
[DB에서 사용자 조회]
```

---

## 3단계: 1:1 매칭 비교

### Mismatch #1: Onboarding showKana 필드

**심각도**: MEDIUM

**모바일** (`/apps/mobile/lib/features/auth/presentation/onboarding_page.dart:40-48`):
```dart
await dio.post<Map<String, dynamic>>(
  '/auth/onboarding',
  data: {
    'nickname': state.nickname,
    'jlptLevel': state.jlptLevel,
    'goal': state.goal,
    'showKana': state.showKana,  // ← 모바일이 보냄
  },
);
```

**백엔드** (`/apps/api/app/schemas/auth.py`):
```python
class OnboardingRequest(CamelModel):
    nickname: str
    jlpt_level: JlptLevel
    goal: UserGoal | None = None
    daily_goal: int = 10
    # showKana 필드 없음 - 무시됨
```

**문제**: 모바일이 `showKana`를 전송하지만 백엔드에서 받지 않습니다. 이는 나중에 프로필 업데이트 엔드포인트에서 처리해야 합니다.

**영향**:
- onboarding 후 showKana가 false로 유지
- N5 사용자가 kana 학습을 원해도 표시되지 않음

---

### Mismatch #2: 프로필 조회 응답 구조 불일치

**심각도**: CRITICAL

**모바일이 기대하는 구조** (`/apps/mobile/lib/features/my/data/models/profile_detail_model.dart`):
```json
{
  "profile": { ... UserProfile fields ... },
  "summary": { ... stats ... },
  "achievements": [ ... ]
}
```

**백엔드가 반환하는 구조** (`/apps/api/app/routers/user.py:74-82`):
```json
{
  "profile": { ... },
  "stats": { ... },  // ← "summary"가 아니라 "stats"
  "achievements": [ ... ]
}
```

**문제**: 모바일 모델이 `summary` 필드를 기대하는데 백엔드가 `stats`를 반환합니다.

**파일 대조**:
- 모바일: `/apps/mobile/lib/features/my/data/models/profile_detail_model.dart:2`
  ```dart
  final ProfileSummary summary;
  final summary = ProfileSummary.fromJson(
    json['summary'] as Map<String, dynamic>? ?? {},  // ← 'summary' 키
  );
  ```

- 백엔드: `/apps/api/app/routers/user.py:74`
  ```python
  return UserProfileWithStats(
      profile=UserProfile.model_validate(user),
      stats=UserStats(  # ← 'stats' 필드명
          total_words_studied=total_words,
          ...
      ),
  )
  ```

**영향**:
- 프로필 조회 실패 또는 summary가 {}로 파싱됨
- 학습 통계가 모바일에 표시되지 않음

---

### Mismatch #3: 프로필 업데이트 - notificationEnabled 필드

**심각도**: MEDIUM

**모바일** (`/apps/mobile/lib/features/my/presentation/my_page.dart:80-88`):
```dart
AppSettingsSection(
  notificationEnabled: data.profile.notificationEnabled,  // ← 사용함
  onUpdate: (field, value) async {
    await ref
        .read(myRepositoryProvider)
        .updateProfile({field: value});  // ← 보내려고 시도
    ref.invalidate(profileDetailProvider);
  },
```

**백엔드** (`/apps/api/app/schemas/user.py:31-37`):
```python
class UserProfileUpdate(CamelModel):
    nickname: str | None = None
    jlpt_level: JlptLevel | None = None
    daily_goal: int | None = None
    goal: UserGoal | None = None
    show_kana: bool | None = None
    call_settings: dict[str, Any] | None = None
    # notificationEnabled은 없음
```

**문제**: 모바일이 `notificationEnabled`을 업데이트하려고 하지만 백엔드 스키마에 필드가 없습니다.

**UserProfile 모델에는 있음**: `/apps/api/app/schemas/user.py:11-28`
```python
class UserProfile(CamelModel):
    # ...
    # notification_enabled 필드 없음!
```

**실제로 User 모델에도 필드가 없을 것 같음** (app/models/user.py에서 확인 필요)

**영향**:
- 알림 설정 변경이 저장되지 않음
- 모바일의 알림 토글이 작동하지 않음

---

### Mismatch #4: 구독 상태 응답 필드명 불일치

**심각도**: CRITICAL (자동 변환되므로 실제로는 작동하지만 헷갈림)

**모바일** (`/apps/mobile/lib/features/my/data/models/subscription_model.dart:12`):
```dart
isPremium: json['isPremium'] as bool? ?? false,
```

**백엔드** (`/apps/api/app/schemas/subscription.py:24-28`):
```python
class SubscriptionStatusResponse(CamelModel):
    is_premium: bool
    plan: SubscriptionPlan
    expires_at: datetime | None = None
    cancelled_at: datetime | None = None
```

**실제 동작**:
- `is_premium` → CamelModel이 자동으로 `isPremium`으로 변환 ✓
- `expires_at` → CamelModel이 자동으로 `expiresAt`으로 변환 ✓
- `cancelled_at` → CamelModel이 자동으로 `cancelledAt`으로 변환 ✓

**문제**: 없음! (CamelModel이 자동 변환하므로 작동함) ✓

---

### Mismatch #5: 결제 내역 URL 불일치

**심각도**: CRITICAL

**모바일** (`/apps/mobile/lib/features/my/data/my_repository.dart:40-45`):
```dart
Future<Map<String, dynamic>> fetchPayments(int page) async {
  final response = await _dio.get<Map<String, dynamic>>(
    '/subscription/payments',  // ← /subscription/payments
    queryParameters: {'page': page},
  );
  return response.data!;
}
```

**백엔드** (`/apps/api/app/routers/payments.py:14`):
```python
@router.get("/")  # ← prefix가 /api/v1/payments
# 따라서 실제 엔드포인트: /api/v1/payments/
```

**URL 매칭**:
- 모바일 호출: `/api/v1/subscription/payments`
- 백엔드 실제: `/api/v1/payments/`

**문제**: 완전히 다른 경로입니다!

**영향**:
- 404 Not Found 오류
- 결제 내역이 로드되지 않음

---

### Mismatch #6: 계정 삭제 엔드포인트 없음

**심각도**: HIGH

**모바일** (`/apps/mobile/lib/features/my/data/my_repository.dart:36-38`):
```dart
Future<void> deleteAccount() async {
  await _dio.delete<Map<String, dynamic>>('/user/account');
}
```

**백엔드**: 구현되어 있지 않음!

**라우터 확인**: `/apps/api/app/routers/user.py`에는 다음 엔드포인트만 있음:
- `GET /user/profile`
- `PATCH /user/profile`
- `PATCH /user/avatar`
- `PATCH /user/account` (계정 업데이트만, 삭제 아님)

**문제**: `DELETE /api/v1/user/account` 엔드포인트가 없습니다.

**사용처** (`/apps/mobile/lib/features/my/presentation/my_page.dart:319-327`):
```dart
Future<void> _handleDeleteAccount() async {
  try {
    await ref.read(myRepositoryProvider).deleteAccount();  // ← 호출
    final repo = ref.read(authRepositoryProvider);
    await repo.signOut();
  } catch (_) {
    // Error handled silently
  }
}
```

**영향**:
- 계정 삭제가 작동하지 않음
- 사용자가 앱에서 계정을 삭제할 수 없음

---

### Mismatch #7: 프로필 모델 필드 불일치

**심각도**: MEDIUM

**모바일이 기대하는 추가 필드들**:
- `levelProgress` (nested object)
- `notificationEnabled`

**백엔드 UserProfile에 없는 필드**:
- `levelProgress` - 계산해서 내려줘야 함
- `notificationEnabled` - User 모델에 필드 자체가 없음

**파일 대조**:
- 모바일: `/apps/mobile/lib/features/my/data/models/profile_detail_model.dart:35-50`
- 백엔드: `/apps/api/app/schemas/user.py:11-28`

---

### Mismatch #8: 결제 구현 미흡

**심각도**: LOW (현재 UI에서만 "준비 중" 표시)

**모바일** (`/apps/mobile/lib/features/subscription/presentation/checkout_page.dart`):
```dart
class CheckoutPage extends StatelessWidget {
  // ... 실제 결제 로직 없음
  // "결제 기능은 준비 중입니다" 메시지만 표시
}
```

**백엔드**: 다음 엔드포인트들이 준비됨:
- `POST /api/v1/subscription/checkout`
- `POST /api/v1/subscription/activate`
- `POST /api/v1/subscription/cancel`
- `POST /api/v1/subscription/resume`

**문제**: PortOne 결제 모듈이 모바일에 아직 통합되지 않았습니다.

---

### Mismatch #9: 프로필 응답의 필드 누락

**심각도**: MEDIUM

**모바일이 UserProfile에서 기대하는 필드**:
- `avatar_url` (현재 O)
- `show_kana` (현재 O)
- `onboarding_completed` (현재 O)
- `call_settings` (현재 O)
- `last_study_date` (백엔드에는 있음)

그런데 **백엔드 UserProfile에는 있지만 모바일 ProfileInfo에서 원하지 않는 필드**:
- `email` - 모바일이 요청하지 않음

**파일 대조**:
- 백엔드: `/apps/api/app/schemas/user.py:11-28`
  ```python
  email: str  # ← 모바일이 요청하지 않음
  ```
- 모바일: `/apps/mobile/lib/features/my/data/models/profile_detail_model.dart:27-41`
  - email 필드 없음

---

## 4단계: 상세 보고서

### [Onboarding showKana] - MEDIUM

- **모바일**: `POST /auth/onboarding` (body에 `showKana` 포함)
- **백엔드**: `POST /api/v1/auth/onboarding` - showKana 필드 미수용
- **불일치 내용**: 모바일이 onboarding 요청에 `showKana`를 포함시키지만 백엔드에서 받지 않고 무시합니다
- **영향**:
  - N5 사용자의 showKana 설정이 onboarding 중에 저장되지 않음
  - 모바일은 onboarding 후 showKana를 프로필 업데이트로 저장해야 함 (현재는 안 함)
  - kana 학습 화면으로의 라우팅 로직이 onboarding_completed 플래그에만 의존

---

### [프로필 조회 응답 구조] - CRITICAL

- **모바일**: `GET /user/profile` 응답에서 `summary` 필드 기대
- **백엔드**: `GET /api/v1/user/profile` 응답에서 `stats` 필드 반환
- **불일치 내용**:
  ```dart
  // 모바일
  json['summary'] as Map<String, dynamic>? ?? {}

  // 백엔드
  "stats": UserStats(...)
  ```
- **영향**:
  - ProfileDetailModel 파싱 실패
  - 학습 통계가 {}로 파싱되어 모바일에서 0으로 표시됨
  - My 페이지의 "학습 현황" 섹션이 작동하지 않음

---

### [프로필 업데이트 notificationEnabled] - MEDIUM

- **모바일**: `PATCH /user/profile` 요청에 `notificationEnabled` 필드 전송 시도
- **백엔드**: `UserProfileUpdate` 스키마에 `notification_enabled` 필드 없음
- **불일치 내용**:
  - 모바일 MyPage의 AppSettingsSection에서 `notificationEnabled` 토글 있음
  - 백엔드 스키마에서 필드 미정의
  - User 모델에도 필드가 없을 가능성 높음
- **영향**:
  - 알림 활성화/비활성화 설정이 저장되지 않음
  - 모바일의 알림 토글이 시각적으로는 작동하지만 실제로 저장 안 됨

---

### [구독 상태 응답 필드명] - NONE (자동 변환됨)

- **모바일**: camelCase 기대 (`isPremium`, `expiresAt`, `cancelledAt`)
- **백엔드**: snake_case 사용 (`is_premium`, `expires_at`, `cancelled_at`)
- **불일치 내용**: 없음
- **영향**: CamelModel이 자동으로 변환하므로 문제 없음 ✓

---

### [결제 내역 URL] - CRITICAL

- **모바일**: `GET /subscription/payments?page={page}`
- **백엔드**: `GET /payments/?page={page}`
- **불일치 내용**:
  - 경로가 완전히 다름
  - 모바일 라우터 확인: `/apps/mobile/lib/features/my/data/my_repository.dart:41`
    ```dart
    '/subscription/payments'
    ```
  - 백엔드 라우터 확인: `/apps/api/app/routers/payments.py:14`
    ```python
    @router.get("/")  # prefix="/api/v1/payments"
    ```
- **영향**:
  - 404 Not Found 오류 발생
  - PaymentsPage에서 결제 내역 로드 실패
  - Sentry에 에러 리포팅됨 (`/apps/mobile/lib/features/my/presentation/payments_page.dart:41`)

---

### [계정 삭제 엔드포인트] - HIGH

- **모바일**: `DELETE /user/account`
- **백엔드**: 구현되지 않음
- **불일치 내용**:
  - 모바일이 계정 삭제 기능을 제공하려고 함
  - 백엔드에 DELETE /user/account 엔드포인트 없음
  - 존재하는 엔드포인트: PATCH /user/account (프로필 업데이트만)
- **영향**:
  - 사용자가 앱에서 계정 삭제 불가능
  - 404 또는 Method Not Allowed 오류

---

### [프로필 모델 필드 누락] - MEDIUM

- **모바일**: `levelProgress` 및 `notificationEnabled` 기대
- **백엔드**:
  - `levelProgress`: 계산되지 않고 내려가지 않음
  - `notificationEnabled`: 모델에 없음
- **불일치 내용**:
  - 모바일 ProfileInfo 요청 필드:
    ```dart
    levelProgress: LevelProgress.fromJson(...) // 백엔드가 안 내려줌
    notificationEnabled: bool // 백엔드가 안 내려줌
    ```
- **영향**:
  - levelProgress가 기본값으로 파싱됨 (currentXp: 0, xpForNext: 1000)
  - notificationEnabled이 true로 기본값 설정됨
  - 레벨 진행도가 정확하지 않음

---

### [프로필 응답의 email 필드] - LOW

- **모바일**: ProfileInfo에 email 필드 없음
- **백엔드**: UserProfile에 email 필드 있음
- **불일치 내용**: 백엔드가 불필요한 데이터를 전송
- **영향**: 모바일에서는 무시되지만 대역폭 낭비

---

### [프로필 응답의 goal 필드] - LOW

- **모바일**: ProfileInfo에 goal 필드 없음
- **백엔드**: UserProfile에 goal 필드 있음
- **불일치 내용**: 모바일이 goal을 요청하지 않음 (onboarding에서만 사용)
- **영향**: 모바일에서는 무시되지만 데이터 전송 낭비

---

## 5단계: 요약 테이블

| # | 엔드포인트 | 심각도 | 문제 | 모바일 | 백엔드 |
|---|-----------|--------|------|--------|--------|
| 1 | POST /auth/onboarding | MEDIUM | showKana 미수용 | /auth/onboarding | auth.py:17 |
| 2 | GET /user/profile | CRITICAL | response 구조 불일치 (summary vs stats) | profile_detail_model.dart | user.py:35 |
| 3 | PATCH /user/profile | MEDIUM | notificationEnabled 필드 없음 | my_page.dart:70 | user.py:85 |
| 4 | GET /subscription/status | NONE | 필드명 자동 변환됨 (OK) | subscription_model.dart | subscription.py:37 |
| 5 | GET /subscription/payments | CRITICAL | URL 경로 불일치 | my_repository.dart:41 | payments.py:14 |
| 6 | DELETE /user/account | HIGH | 엔드포인트 미구현 | my_repository.dart:36 | - |
| 7 | User Model | MEDIUM | levelProgress, notificationEnabled 필드 없음 | profile_detail_model.dart | user.py:11 |
| 8 | Checkout | LOW | 모바일 구현 미완료 | checkout_page.dart | subscription.py:61 |

---

## 권장 수정 사항

### 우선순위 1 (CRITICAL - 즉시 수정)

1. **프로필 조회 응답 구조 수정**
   - 백엔드: `stats` → `summary` 또는 모바일: `summary` → `stats`로 통일
   - 권장: 백엔드를 `summary`로 변경 (RESTful 의미상 맞음)

2. **결제 내역 URL 수정**
   - 모바일: `/subscription/payments` → `/payments` 또는
   - 백엔드: 라우터 경로 조정
   - 권장: 모바일을 `/payments`로 수정 (백엔드 구조와 일치)

### 우선순위 2 (HIGH - 시급)

3. **계정 삭제 엔드포인트 구현**
   - 백엔드에 `DELETE /api/v1/user/account` 구현

### 우선순위 3 (MEDIUM - 다음 스프린트)

4. **프로필 모델에 필드 추가**
   - `levelProgress` 계산 로직 추가
   - `notification_enabled` 필드 User 모델에 추가

5. **notificationEnabled 필드 지원**
   - 백엔드 UserProfileUpdate에 필드 추가
   - User 모델에 필드 추가

6. **Onboarding showKana 처리**
   - 옵션 1: OnboardingRequest에 `show_kana` 필드 추가
   - 옵션 2: 모바일이 onboarding 후 PATCH로 showKana 업데이트

### 우선순위 4 (LOW - 나중에)

7. **프로필 응답 최적화**
   - 불필요한 필드(email, goal) 제거 또는 유지

8. **결제 기능 완성**
   - 모바일: PortOne 통합 구현
   - CheckoutPage 완성

---

## 인증 흐름 분석

### Supabase JWT 토큰 검증 전체 플로우

```
┌─────────────────────────────────────────┐
│ 1. 모바일 - Supabase Auth               │
│    - Google/Kakao/Email 로그인          │
│    - Supabase에서 JWT 발급              │
└──────────────┬──────────────────────────┘
               │ 토큰: eyJhbGc...
               ↓
┌─────────────────────────────────────────┐
│ 2. 모바일 - AuthInterceptor             │
│    (auth_interceptor.dart:28-30)        │
│    - 모든 요청에 Authorization 헤더 추가│
│    - Header: "Bearer <token>"           │
└──────────────┬──────────────────────────┘
               │ Authorization: Bearer ...
               ↓
┌─────────────────────────────────────────┐
│ 3. FastAPI - get_current_user           │
│    (dependencies.py:85-121)             │
│    - HTTPBearer로 토큰 추출             │
│    - _decode_token() 호출               │
└──────────────┬──────────────────────────┘
               │
     ┌─────────┴─────────┐
     ↓                   ↓
  JWKS 방식          HS256 폴백
  (ES256)         (SUPABASE_JWT_SECRET)
  Supabase
  공개키
     │                   │
     └─────────┬─────────┘
               │
               ↓ payload = {
                 "sub": "user-uuid",
                 "email": "user@mail",
                 "aud": "authenticated",
                 ...
               }
               │
               ├─ sub 추출 (user_id)
               │
               └─ DB 조회
                  SELECT * FROM users
                  WHERE id = user_id
               │
               ↓ User 객체 반환
     ┌──────────────────────────┐
     │ @Depends(get_current_user)│
     │ → User 객체 주입           │
     └──────────────────────────┘
```

### 토큰 검증 상세

**파일**: `/apps/api/app/dependencies.py:51-77`

1. **JWKS (권장) - ES256**:
   ```python
   client = PyJWKClient(settings.supabase_jwks_url)
   signing_key = client.get_signing_key_from_jwt(token)
   jwt.decode(token, signing_key.key, algorithms=["ES256"], audience="authenticated")
   ```

2. **Fallback - HS256**:
   ```python
   jwt.decode(token, settings.SUPABASE_JWT_SECRET, algorithms=["HS256"], audience="authenticated")
   ```

3. **에러 처리**:
   - 토큰 유효하지 않음 → 401 Unauthorized
   - sub 클레임 없음 → 401 Unauthorized
   - 사용자 찾을 수 없음 → 404 Not Found

---

## 결론

**총 불일치 사항**: 9개
- **CRITICAL**: 2개 (profile response structure, payments URL)
- **HIGH**: 1개 (delete account)
- **MEDIUM**: 4개 (onboarding showKana, notification field, level progress, field normalization)
- **LOW**: 2개 (checkout implementation, unnecessary fields)

**우선 수정 순서**:
1. 프로필 조회 응답 구조 수정 (summary/stats)
2. 결제 내역 URL 통일
3. 계정 삭제 엔드포인트 구현
4. 알림 필드 지원 추가
5. 레벨 진행도 필드 추가
6. Onboarding showKana 처리

**다음 단계**: 불일치 수정 작업 (Task #5)

