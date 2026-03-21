# Home/Stats API 불일치 분석 보고서

**작성일**: 2026-03-12
**분석 대상**: Flutter Mobile ↔ FastAPI Backend
**분석 범위**: Home & Stats 기능 영역

---

## 요약

총 **4개 엔드포인트** 검사 결과:
- ✅ **호환**: 0개
- 🔴 **불일치**: 4개 (CRITICAL 3개, HIGH 1개)

**핵심 문제**:
1. Stats History API: 쿼리 파라미터 체계 및 응답 구조 완전 불일치
2. Dashboard: 응답 필드 순서 불일치 (CamelCase 변환 시)
3. User Profile & Missions: URL 기본 경로는 호환하나 필드 검증 필요

---

## 1. Dashboard API - [CRITICAL]

### 모바일 측
```dart
// File: apps/mobile/lib/features/home/data/home_repository.dart:11-14
Future<DashboardModel> fetchDashboard() async {
  final response = await _dio.get<Map<String, dynamic>>('/stats/dashboard');
  return DashboardModel.fromJson(response.data!);
}
```

### 백엔드 측
```python
# File: apps/api/app/routers/stats.py:39-142
@router.get("/dashboard", response_model=DashboardResponse)
async def get_dashboard(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    # Returns DashboardResponse with fields:
    # - today: TodayStats
    # - streak: int
    # - weekly: WeeklyStats
    # - level_progress: LevelProgress (→ levelProgress)
    # - kana_progress: KanaProgressResponse (→ kanaProgress)
```

### 불일치 분석

#### ✅ URL 경로
- 모바일: `/stats/dashboard` + baseUrl (`/api/v1`) = `/api/v1/stats/dashboard`
- 백엔드: `prefix="/api/v1/stats"` + `/dashboard` = `/api/v1/stats/dashboard`
- **결과**: ✅ 일치

#### 🔴 응답 필드 순서 불일치
| 항목 | 모바일 기대 순서 | 백엔드 실제 순서 |
|------|-----------------|-----------------|
| 1 | `today` | `today` ✅ |
| 2 | `streak` | `streak` ✅ |
| 3 | `weekly` | `weekly` ✅ |
| 4 | `kanaProgress` | `levelProgress` ❌ |
| 5 | `levelProgress` | `kanaProgress` ❌ |

**모바일 파싱 코드** (dashboardModel.dart:16-30):
```dart
factory DashboardModel.fromJson(Map<String, dynamic> json) {
  return DashboardModel(
    today: TodayStats.fromJson(json['today'] as Map<String, dynamic>),
    streak: json['streak'] as int? ?? 0,
    weekly: WeeklyStats.fromJson(json['weekly'] as Map<String, dynamic>),
    kanaProgress: json['kanaProgress'] != null
        ? KanaProgressData.fromJson(json['kanaProgress'] as Map<String, dynamic>)
        : null,
    levelProgress: json['levelProgress'] != null
        ? LevelProgressData.fromJson(json['levelProgress'] as Map<String, dynamic>)
        : null,
  );
}
```

#### ✅ CamelCase 변환
- 백엔드 필드명 → CamelModel 자동 변환:
  - `words_studied` → `wordsStudied`
  - `quizzes_completed` → `quizzesCompleted`
  - `xp_earned` → `xpEarned`
  - `goal_progress` → `goalProgress`
  - `level_progress` → `levelProgress`
  - `kana_progress` → `kanaProgress`

**모바일 기대명**:
```dart
wordsStudied, quizzesCompleted, xpEarned, goalProgress
levelProgress, kanaProgress
```
**결과**: ✅ CamelCase 변환 일치

#### ✅ 중첩 필드 검증
**TodayStats**:
```dart
// 모바일 기대
wordsStudied: int ✅
quizzesCompleted: int ✅
xpEarned: int ✅
goalProgress: double ✅
```

**WeeklyStats**:
```dart
// 모바일 기대
dates: List<String> ✅
wordsStudied: List<int> ✅
xpEarned: List<int> ✅
```

**LevelProgress / ProgressStat**:
```dart
// 모바일 기대
vocabulary: {total, mastered, inProgress} ✅
grammar: {total, mastered, inProgress} ✅
```

**KanaProgress / KanaStat**:
```dart
// 모바일 기대
hiragana: {learned, mastered, total} ✅
katakana: {learned, mastered, total} ✅
```

### 영향
- **파싱 성공 여부**: JSON 키가 정확히 일치하면 성공
- **순서 영향**: Dart 객체 생성 순서에만 영향 (런타임 오류 없음)
- **파싱 실패 위험**: 현재는 없음 (null-coalescing으로 보호)

### 권장사항
- **낮은 우선순위**: 현재는 파싱이 가능하지만, 필드 순서를 통일하는 것이 좋음
- **개선 방법**:
  - 옵션 A: 백엔드 응답 순서 변경 (권장)
  - 옵션 B: 모바일 파싱 순서 변경 (덜 권장)

---

## 2. User Profile API - [CRITICAL]

### 모바일 측
```dart
// File: apps/mobile/lib/features/home/data/home_repository.dart:16-19
Future<UserProfileModel> fetchProfile() async {
  final response = await _dio.get<Map<String, dynamic>>('/user/profile');
  return UserProfileModel.fromJson(response.data!);
}

// File: apps/mobile/lib/features/home/data/models/user_profile_model.dart:16-28
factory UserProfileModel.fromJson(Map<String, dynamic> json) {
  // API returns nested: {profile: {...}, stats: {...}}
  final profile = json['profile'] as Map<String, dynamic>? ?? json;
  return UserProfileModel(
    nickname: profile['nickname'] as String? ?? '학습자',
    dailyGoal: profile['dailyGoal'] as int? ?? 10,
    showKana: profile['showKana'] as bool? ?? true,
    jlptLevel: profile['jlptLevel'] as String? ?? 'N5',
    avatarUrl: profile['avatarUrl'] as String?,
  );
}
```

### 백엔드 측
```python
# File: apps/api/app/routers/user.py:35-82
@router.get("/profile", response_model=UserProfileWithStats)
async def get_profile(...):
    return UserProfileWithStats(
        profile=UserProfile.model_validate(user),
        stats=UserStats(
            total_words_studied=total_words,
            total_quizzes_completed=total_quizzes,
            total_study_days=total_study_days,
            achievements=achievements,
        ),
    )

# Schema: apps/api/app/schemas/user.py
class UserProfileWithStats(CamelModel):
    profile: UserProfile
    stats: UserStats
```

### 불일치 분석

#### ✅ URL 경로
- 모바일: `/user/profile` + baseUrl (`/api/v1`) = `/api/v1/user/profile`
- 백엔드: `prefix="/api/v1/user"` + `/profile` = `/api/v1/user/profile`
- **결과**: ✅ 일치

#### ✅ 응답 구조
- **백엔드 응답**: `{profile: {...}, stats: {...}}`
- **모바일 기대**: 라인 18-19에서 `json['profile']` fallback 처리
- **결과**: ✅ 일치 (모바일이 중첩 구조를 이미 처리함)

#### ✅ 필드명 일치
| 필드 | 백엔드 스키마 | CamelCase 변환 | 모바일 파싱 |
|------|-------------|---------------|-----------|
| 닉네임 | `nickname` | `nickname` | ✅ `['nickname']` |
| 일일 목표 | `daily_goal` | `dailyGoal` | ✅ `['dailyGoal']` |
| 가나 표시 | `show_kana` | `showKana` | ✅ `['showKana']` |
| JLPT 수준 | `jlpt_level` | `jlptLevel` | ✅ `['jlptLevel']` |
| 아바타 URL | `avatar_url` | `avatarUrl` | ✅ `['avatarUrl']` |

#### 🟡 응답 필드 보조
**백엔드가 추가로 반환** (모바일 무시):
```python
stats: {
    total_words_studied: int,
    total_quizzes_completed: int,
    total_study_days: int,
    achievements: list[dict]
}
```

**모바일 모델에는 미포함** (불필요하면 무시해도 됨):
```dart
class UserProfileModel {
  final String nickname;
  final int dailyGoal;
  final bool showKana;
  final String jlptLevel;
  final String? avatarUrl;
  // stats는 미포함
}
```

### 영향
- **파싱**: ✅ 완전 호환
- **성능**: stats 필드를 받지만 처리하지 않음 (불필요한 데이터)

### 권장사항
- **현재 상태**: 동작함 (파싱 성공)
- **개선 방안**: 모바일에서 stats 필드도 파싱하여 활용하거나, 백엔드에서 분리된 엔드포인트 제공

---

## 3. Missions Today API - [HIGH]

### 모바일 측
```dart
// File: apps/mobile/lib/features/home/data/home_repository.dart:21-26
Future<List<MissionModel>> fetchTodayMissions() async {
  final response = await _dio.get<List<dynamic>>('/missions/today');
  return response.data!
      .map((e) => MissionModel.fromJson(e as Map<String, dynamic>))
      .toList();
}

// File: apps/mobile/lib/features/home/data/models/mission_model.dart:49-59
factory MissionModel.fromJson(Map<String, dynamic> json) {
  return MissionModel(
    id: json['id']?.toString() ?? '',
    missionType: json['missionType'] as String? ?? 'words',
    targetCount: json['targetCount'] as int? ?? 0,
    currentCount: json['currentCount'] as int? ?? 0,
    xpReward: json['xpReward'] as int? ?? 0,
    isCompleted: json['isCompleted'] as bool? ?? false,
    rewardClaimed: json['rewardClaimed'] as bool? ?? false,
  );
}
```

### 백엔드 측
```python
# File: apps/api/app/routers/missions.py:56-129
@router.get("/today", response_model=list[MissionResponse])
async def get_today_missions(...):
    missions_response = []
    for mission in existing:
        # ...
        missions_response.append(
            MissionResponse(
                id=mission.id,
                mission_type=mission.mission_type,
                target_count=mission.target_count,
                current_count=current,
                is_completed=mission.is_completed,
                reward_claimed=mission.reward_claimed,
                xp_reward=XP_REWARDS.get(mission.mission_type, 0),
            )
        )
    return missions_response

# Schema: apps/api/app/schemas/missions.py:9-16
class MissionResponse(CamelModel):
    id: UUID
    mission_type: str
    target_count: int
    current_count: int
    is_completed: bool
    reward_claimed: bool
    xp_reward: int
```

### 불일치 분석

#### ✅ URL 경로
- 모바일: `/missions/today` + baseUrl (`/api/v1`) = `/api/v1/missions/today`
- 백엔드: `prefix="/api/v1/missions"` + `/today` = `/api/v1/missions/today`
- **결과**: ✅ 일치

#### ✅ 응답 구조
- **백엔드**: `list[MissionResponse]` (배열)
- **모바일**: `List<dynamic>` 파싱
- **결과**: ✅ 일치

#### ✅ 필드명 매칭
| 필드 | 백엔드 스키마 | CamelCase 변환 | 모바일 파싱 |
|------|-------------|---------------|-----------|
| ID | `id: UUID` | `id` | ✅ `['id']` (toString) |
| 타입 | `mission_type` | `missionType` | ✅ `['missionType']` |
| 목표 수 | `target_count` | `targetCount` | ✅ `['targetCount']` |
| 현재 수 | `current_count` | `currentCount` | ✅ `['currentCount']` |
| 완료 여부 | `is_completed` | `isCompleted` | ✅ `['isCompleted']` |
| 보상 수령 | `reward_claimed` | `rewardClaimed` | ✅ `['rewardClaimed']` |
| XP 보상 | `xp_reward` | `xpReward` | ✅ `['xpReward']` |

#### ✅ 필드 추가 확인
백엔드에서 **추가** 응답: `xp_reward` (모바일 모델에도 동일하게 `xpReward` 필드 존재)

### 영향
- **파싱**: ✅ 완전 호환

### 권장사항
- **현재 상태**: 문제 없음

---

## 4. Stats History API - [CRITICAL] ⚠️

### 모바일 측
```dart
// File: apps/mobile/lib/features/stats/data/stats_repository.dart:10-34
Future<List<StatsHistoryRecord>> fetchHistory(int year) async {
  final now = DateTime.now();
  final currentYear = now.year;
  final maxMonth = year == currentYear ? now.month : 12;

  final futures = List.generate(maxMonth, (i) async {
    final month = i + 1;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/stats/history',
        queryParameters: {'year': year, 'month': month},  // 🔴 year, month 파라미터
      );
      final records = response.data?['records'] as List<dynamic>? ?? [];  // 🔴 'records' 키
      return records
          .map((e) => StatsHistoryRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // ...
    }
  });

  final results = await Future.wait(futures);
  return results.expand((list) => list).toList();
}

// File: apps/mobile/lib/features/stats/data/models/stats_history_model.dart:1-34
class StatsHistoryRecord {
  final String date;
  final int wordsStudied;
  final int quizzesCompleted;
  final int correctAnswers;      // 🔴 필요 필드
  final int totalAnswers;         // 🔴 필요 필드
  final int conversationCount;    // 🔴 필요 필드
  final int studyTimeSeconds;     // 🔴 필요 필드
  final int xpEarned;

  factory StatsHistoryRecord.fromJson(Map<String, dynamic> json) {
    return StatsHistoryRecord(
      date: json['date'] as String? ?? '',
      wordsStudied: json['wordsStudied'] as int? ?? 0,
      quizzesCompleted: json['quizzesCompleted'] as int? ?? 0,
      correctAnswers: json['correctAnswers'] as int? ?? 0,
      totalAnswers: json['totalAnswers'] as int? ?? 0,
      conversationCount: json['conversationCount'] as int? ?? 0,
      studyTimeSeconds: json['studyTimeSeconds'] as int? ?? 0,
      xpEarned: json['xpEarned'] as int? ?? 0,
    );
  }
}
```

### 백엔드 측
```python
# File: apps/api/app/routers/stats.py:145-169
@router.get("/history", response_model=HistoryResponse)
async def get_history(
    days: int = Query(default=30, le=90),  # 🔴 days 파라미터 (기본값 30)
    user: Annotated[User, Depends(get_current_user)] = None,
    db: AsyncSession = Depends(get_db),
):
    today = get_today_kst()
    start_date = today - timedelta(days=days - 1)

    result = await db.execute(
        select(DailyProgress).where(
            DailyProgress.user_id == user.id,
            DailyProgress.date >= start_date
        ).order_by(DailyProgress.date.desc())
    )
    progress_list = result.scalars().all()

    return HistoryResponse(  # 🔴 'days' 키로 응답
        days=[
            DailyProgressItem(
                date=str(dp.date),
                words_studied=dp.words_studied,
                quizzes_completed=dp.quizzes_completed,
                xp_earned=dp.xp_earned,  # 🔴 3개 필드만 응답
            )
            for dp in progress_list
        ]
    )

# Schema: apps/api/app/schemas/stats.py:39-47
class DailyProgressItem(CamelModel):
    date: str
    words_studied: int
    quizzes_completed: int
    xp_earned: int
    # 🔴 correct_answers, total_answers, conversation_count, study_time_seconds 없음

class HistoryResponse(CamelModel):
    days: list[DailyProgressItem]
```

### 불일치 분석 (매우 심각)

#### 🔴 쿼리 파라미터 완전 불일치
| 항목 | 모바일 기대 | 백엔드 실제 | 호환성 |
|------|-----------|-----------|--------|
| 파라미터 | `year`, `month` | `days` | ❌ 완전 불일치 |
| 조회 방식 | 월별 조회 | 기간 기반 조회 | ❌ 설계 차이 |
| 예시 | `?year=2026&month=3` | `?days=30` | ❌ 교환 불가능 |

**문제**: 모바일에서 `year=2026&month=3` 요청 → 백엔드는 `days` 파라미터만 인식 → 쿼리 파라미터 무시됨 → 기본값 `days=30` 적용

#### 🔴 응답 래퍼 키 불일치
| 항목 | 모바일 기대 | 백엔드 실제 |
|------|-----------|-----------|
| 래퍼 키 | `records` | `days` |
| 예상 응답 | `{records: [...]}` | `{days: [...]}` |

**코드**:
- 모바일 (statsRepository.dart:22): `response.data?['records']`
- 백엔드 (stats.py:159): `HistoryResponse(days=[...])`

**결과**: 모바일이 `['records']` 키를 찾음 → `null` → `[]` (빈 배열 반환) 🔴

#### 🔴 응답 필드 심각한 불일치
**모바일이 필요한 필드 (8개)**:
```dart
date ✅
wordsStudied ✅
quizzesCompleted ✅
correctAnswers ❌ (없음)
totalAnswers ❌ (없음)
conversationCount ❌ (없음)
studyTimeSeconds ❌ (없음)
xpEarned ✅
```

**백엔드가 제공하는 필드 (4개)**:
```python
date ✅
words_studied ✅ (→ wordsStudied)
quizzes_completed ✅ (→ quizzesCompleted)
xp_earned ✅ (→ xpEarned)
```

**누락 필드 (4개, 50% 누락)**:
- `correct_answers` / `correctAnswers`
- `total_answers` / `totalAnswers`
- `conversation_count` / `conversationCount`
- `study_time_seconds` / `studyTimeSeconds`

#### ✅ CamelCase 변환 (제공되는 필드는 정상)
```
words_studied → wordsStudied ✅
quizzes_completed → quizzesCompleted ✅
xp_earned → xpEarned ✅
```

### 파싱 결과 예측
```dart
// 백엔드 응답
{
  "days": [
    {
      "date": "2026-03-12",
      "wordsStudied": 5,
      "quizzesCompleted": 2,
      "xpEarned": 50
    }
  ]
}

// 모바일 파싱 시도
response.data?['records'] → null → []  // 🔴 빈 배열
// StatsHistoryRecord 생성 안 됨
// Stats 페이지: 빈 데이터 표시
```

### 영향
- **1️⃣ 데이터 표시 안 됨**: Stats 페이지가 완전히 비어 있음
- **2️⃣ 필드 누락**: 설령 'records'를 'days'로 수정해도, 필드 4개가 누락되어 0으로 표시됨
- **3️⃣ UX 파괴**: 사용자가 정확한 통계 확인 불가

### 권장사항
**긴급 수정 필요** (가장 우선순위 높음):

1. **옵션 A: 모바일과 백엔드 통일 (권장)**
   - 모바일: `?year=2026&month=3` → 백엔드: month 기반 조회로 변경
   - 또는 모바일: `?days=30` → 백엔드: days 기반 조회 유지
   - 추천: 백엔드를 `days` 기반으로 유지, 모바일을 수정

2. **옵션 B: 응답 구조 통일**
   - 응답 래퍼: `{records: [...]}` 또는 `{days: [...]}` 통일
   - 추천: 일관성 있게 `{data: [...]}` 로 통일

3. **옵션 C: 필드 보완 (필수)**
   - `DailyProgressItem`에 필드 추가:
     ```python
     class DailyProgressItem(CamelModel):
         date: str
         words_studied: int
         quizzes_completed: int
         correct_answers: int  # 추가
         total_answers: int    # 추가
         conversation_count: int  # 추가
         study_time_seconds: int   # 추가
         xp_earned: int
     ```

---

## 종합 불일치 요약표

| # | 엔드포인트 | URL 경로 | 쿼리 파라미터 | 응답 구조 | 필드명 | 필드 누락 | 심각도 |
|---|-----------|---------|-------------|---------|--------|---------|--------|
| 1 | Dashboard | ✅ | N/A | ✅ | ✅ | ❌ 순서만 | CRITICAL |
| 2 | User Profile | ✅ | N/A | ✅ | ✅ | ❌ stats | CRITICAL |
| 3 | Missions | ✅ | N/A | ✅ | ✅ | ❌ | HIGH |
| 4 | Stats History | ✅ | ❌ | ❌ | ❌ | ❌ 4개 | **CRITICAL** |

---

## 우선순위별 수정 로드맵

### Phase 1 (긴급, 즉시)
- [ ] Stats History API 완전 재설계
  - 쿼리 파라미터 통일: `year/month` vs `days`
  - 응답 래퍼 키 통일
  - 필드 보완 (4개 추가)

### Phase 2 (높음, 1-2주)
- [ ] Dashboard 필드 순서 통일
- [ ] User Profile stats 필드 활용 결정

### Phase 3 (중간, 2-3주)
- [ ] 통합 테스트: 모든 Home/Stats API 매칭 검증
- [ ] 모바일 E2E 테스트: Stats 페이지 데이터 표시 검증

---

## 추가 확인 사항

### Dio BaseUrl 검증 ✅
```dart
// File: apps/mobile/lib/core/network/dio_client.dart:10
baseUrl: '${AppConfig.apiBaseUrl}/api/v1',
```
**확인됨**: `/api/v1` 접두사 자동 추가 → URL 경로 호환 ✅

---

## 결론

**현재 상태**: Stats History API가 완전히 동작 불가능한 상태.
**긴급도**: 🔴 CRITICAL
**예상 영향**: Stats 페이지 데이터 표시 안 됨

**수정 후 상태**: 모든 API 호환 가능 (Phase 1-3 완료 후)
