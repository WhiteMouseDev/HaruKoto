# 하루코토 Flutter 네이티브 전환 로드맵

> **작성일**: 2026-03-10
> **현재 상태**: Next.js 웹앱 + Flutter WebView 래퍼
> **목표**: Flutter 네이티브 앱으로 점진적 전환

---

## 1. 아키텍처 개요

### 1.1 현재 구조

```
[Flutter Shell]  ←WebView→  [Next.js 웹앱]  ←API→  [Supabase]
   얇은 래퍼                    모든 로직           DB/Auth
```

### 1.2 전환 후 구조

```
[Flutter 네이티브 앱]  ←HTTP→  [Next.js API Routes]  ←Prisma→  [Supabase PostgreSQL]
   UI + 로컬 캐시               비즈니스 로직                     DB/Auth
        │
        ├── FCM (푸시 알림)
        ├── Drift/SQLite (오프라인 캐시)
        └── Supabase Auth (인증)

[Next.js 웹앱]  ← 기존 유저용, 기능 동결 상태로 유지
```

### 1.3 핵심 원칙

- **백엔드는 건드리지 않는다** — 기존 52개 API Routes를 Flutter에서 HTTP로 호출
- **점진적 전환** — 한 화면씩 네이티브로 교체, 미완성 화면은 WebView 폴백
- **오프라인 퍼스트** — 학습 데이터는 로컬 캐시 우선, 온라인 시 동기화

---

## 2. 기술 스택

### 2.1 코어

| 카테고리 | 패키지 | 버전 | 선정 이유 |
|----------|--------|------|-----------|
| **Framework** | Flutter | 3.41.x (latest stable) | 2026.02 릴리즈, Dart 3.8+ |
| **언어** | Dart | 3.8+ | null safety, pattern matching, sealed class |

### 2.2 상태 관리

| 카테고리 | 패키지 | 버전 | 선정 이유 |
|----------|--------|------|-----------|
| **서버 상태 + 클라이언트 상태** | `flutter_riverpod` | ^3.3.0 | 2026 기준 Flutter 상태관리 1위. 자동 재시도, 오프라인 캐시 내장, 컴파일 타임 안전성. 웹앱의 TanStack Query + Zustand를 하나로 대체 |
| **코드 생성** | `riverpod_generator` | ^3.x | `@riverpod` 어노테이션으로 보일러플레이트 제거 |
| **Lint** | `riverpod_lint` | ^3.x | Riverpod 전용 린트 규칙 |

**Riverpod 3.0 선정 이유 (vs BLoC):**
- 웹앱의 TanStack Query(서버 상태) + Zustand(클라이언트 상태)와 개념이 1:1 매핑
- 자동 재시도(네트워크 실패 시) — 모바일 환경 필수
- 오프라인 캐시 실험적 지원 내장
- BLoC 대비 보일러플레이트 적음 — 1인 개발자에게 유리
- 스타트업/컨슈머 앱에 적합 (BLoC은 엔터프라이즈/금융 앱에 적합)

### 2.3 네트워킹

| 카테고리 | 패키지 | 버전 | 선정 이유 |
|----------|--------|------|-----------|
| **HTTP 클라이언트** | `dio` | ^5.x | 인터셉터, 재시도, 토큰 갱신, 요청 취소 |
| **Supabase 클라이언트** | `supabase_flutter` | ^2.x | Auth + Realtime + Storage |
| **연결 상태 감지** | `connectivity_plus` | ^6.x | 온/오프라인 상태 감지 |

### 2.4 로컬 저장소 / 오프라인 캐시

| 카테고리 | 패키지 | 버전 | 선정 이유 |
|----------|--------|------|-----------|
| **로컬 DB** | `drift` + `drift_flutter` | ^2.32.x | 타입 세이프 SQLite ORM, 리액티브 쿼리, 오프라인 학습 데이터 캐시 |
| **Key-Value 저장소** | `shared_preferences` | ^2.x | 설정, 토큰, 간단한 상태 |
| **보안 저장소** | `flutter_secure_storage` | ^9.x | 인증 토큰, 민감 정보 |

**Drift 선정 이유 (vs Hive, Isar):**
- PostgreSQL(Supabase)과 동일한 SQL 기반 — 스키마 매핑이 자연스러움
- 타입 세이프 쿼리 (Prisma와 유사한 개발 경험)
- 리액티브 스트림 지원 (데이터 변경 시 UI 자동 업데이트)
- 마이그레이션 시스템 내장

### 2.5 라우팅

| 카테고리 | 패키지 | 버전 | 선정 이유 |
|----------|--------|------|-----------|
| **라우터** | `go_router` | ^14.x | Flutter 공식 추천, 딥링크, 네비게이션 가드 |

### 2.6 UI / 디자인

| 카테고리 | 패키지 | 버전 | 선정 이유 |
|----------|--------|------|-----------|
| **아이콘** | `lucide_icons` | ^0.x | 웹앱과 동일한 아이콘 세트 유지 |
| **폰트** | `google_fonts` | ^6.x | Noto Sans JP/KR (웹앱과 동일) |
| **테마** | `flex_color_scheme` | ^8.x | Light/Dark 테마 시스템 |
| **애니메이션** | Flutter 내장 (`AnimationController`, `Hero`, `PageTransition`) | — | Framer Motion 대체, 추가 패키지 불필요 |
| **Shimmer/Skeleton** | `shimmer` | ^3.x | 로딩 상태 표시 |
| **Toast/Snackbar** | `fluttertoast` | ^8.x | 웹앱의 sonner 대체 |
| **Pull to Refresh** | Flutter 내장 (`RefreshIndicator`) | — | |

### 2.7 푸시 알림

| 카테고리 | 패키지 | 버전 | 선정 이유 |
|----------|--------|------|-----------|
| **FCM** | `firebase_messaging` | ^15.x | 푸시 알림 수신 |
| **Firebase Core** | `firebase_core` | ^3.x | FCM 의존성 |
| **로컬 알림** | `flutter_local_notifications` | ^18.x | 포그라운드 알림 표시, 예약 알림 |

### 2.8 오디오 (AI 회화용)

| 카테고리 | 패키지 | 버전 | 선정 이유 |
|----------|--------|------|-----------|
| **오디오 녹음** | `record` | ^5.x | PCM 녹음 (음성 통화) |
| **오디오 재생** | `just_audio` | ^0.9.x | TTS 재생, 단어 발음 |
| **WebSocket** | `web_socket_channel` | ^3.x | Gemini Live 스트리밍 |

### 2.9 결제

| 카테고리 | 패키지 | 버전 | 선정 이유 |
|----------|--------|------|-----------|
| **인앱 결제** | `in_app_purchase` | ^3.x | Apple IAP / Google Play Billing (스토어 정책상 필수) |
| **PortOne 폴백** | WebView 내 처리 | — | 웹 결제 플로우 재사용 가능 |

> Apple/Google 스토어 정책상 디지털 콘텐츠 결제는 인앱 결제를 사용해야 합니다.
> 기존 PortOne(카드/카카오페이) 결제는 웹에서만 유지하고, 앱에서는 IAP로 전환 검토가 필요합니다.

### 2.10 유틸리티

| 카테고리 | 패키지 | 버전 | 선정 이유 |
|----------|--------|------|-----------|
| **코드 생성** | `build_runner` | ^2.4.x | Drift, Riverpod, JSON 직렬화 코드 생성 |
| **JSON 직렬화** | `freezed` + `json_serializable` | ^2.x | 불변 모델 + 자동 JSON 변환 |
| **날짜/시간** | `intl` | ^0.19.x | 한국어/일본어 날짜 포맷 |
| **에러 모니터링** | `sentry_flutter` | ^8.x | 웹앱의 Sentry와 같은 프로젝트로 통합 |
| **환경 변수** | `envied` | ^1.x | .env 파일 관리, 난독화 지원 |
| **이미지** | `cached_network_image` | ^3.x | 아바타, 캐릭터 이미지 캐시 |

### 2.11 개발/테스트

| 카테고리 | 패키지 | 버전 | 선정 이유 |
|----------|--------|------|-----------|
| **테스트** | `flutter_test` (내장) | — | 위젯/유닛 테스트 |
| **목킹** | `mocktail` | ^1.x | 테스트용 목 객체 |
| **린트** | `very_good_analysis` | ^7.x | 엄격한 린트 규칙 세트 |

---

## 3. 프로젝트 구조

```
apps/mobile/lib/
├── main.dart                  # 앱 진입점, Supabase/Firebase 초기화
├── app.dart                   # MaterialApp.router 설정
│
├── core/                      # 앱 전역 설정
│   ├── constants/             # 색상, 사이즈, URL 상수
│   ├── theme/                 # Light/Dark ThemeData
│   ├── router/                # GoRouter 설정 + 인증 가드
│   └── network/               # Dio 인스턴스, 인터셉터, 에러 핸들링
│
├── features/                  # 기능별 모듈 (Feature-first 구조)
│   ├── auth/
│   │   ├── data/              # API 호출, 모델
│   │   ├── providers/         # Riverpod 프로바이더
│   │   └── presentation/      # 로그인, 온보딩 화면
│   │
│   ├── home/
│   │   ├── data/
│   │   ├── providers/
│   │   └── presentation/
│   │
│   ├── study/
│   │   ├── data/
│   │   ├── providers/
│   │   └── presentation/
│   │       ├── study_page.dart
│   │       ├── quiz_page.dart
│   │       └── result_page.dart
│   │
│   ├── kana/
│   │   ├── data/
│   │   ├── providers/
│   │   └── presentation/
│   │
│   ├── chat/
│   │   ├── data/
│   │   ├── providers/
│   │   └── presentation/
│   │       ├── chat_list_page.dart
│   │       ├── chat_room_page.dart
│   │       └── voice_call_page.dart
│   │
│   ├── stats/
│   │   ├── data/
│   │   ├── providers/
│   │   └── presentation/
│   │
│   ├── my/
│   │   ├── data/
│   │   ├── providers/
│   │   └── presentation/
│   │
│   └── subscription/
│       ├── data/
│       ├── providers/
│       └── presentation/
│
├── shared/                    # 공유 컴포넌트
│   ├── widgets/               # 재사용 위젯 (버튼, 카드, 바텀네비 등)
│   ├── models/                # 공유 데이터 모델 (User, Vocabulary 등)
│   └── providers/             # 전역 프로바이더 (인증 상태, 테마 등)
│
└── local_db/                  # Drift 로컬 DB
    ├── database.dart          # DB 인스턴스
    ├── tables/                # 테이블 정의 (캐시용)
    └── daos/                  # Data Access Objects
```

---

## 4. 핵심 설계

### 4.1 서버 상태 관리

웹앱의 TanStack Query → Riverpod 3.0으로 대체합니다.

```dart
// 웹: TanStack Query
// const { data } = useQuery({ queryKey: ['dashboard'], queryFn: fetchDashboard });

// Flutter: Riverpod
@riverpod
Future<DashboardData> dashboard(Ref ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/api/v1/stats/dashboard');
  return DashboardData.fromJson(response.data);
}

// UI에서 사용
final dashboard = ref.watch(dashboardProvider);
dashboard.when(
  data: (data) => DashboardView(data: data),
  loading: () => const DashboardSkeleton(),
  error: (e, st) => ErrorView(error: e, onRetry: () => ref.invalidate(dashboardProvider)),
);
```

**자동 재시도**: Riverpod 3.0은 네트워크 실패 시 자동 재시도를 내장하고 있어 모바일 환경에 적합합니다.

### 4.2 클라이언트 상태 관리

웹앱의 Zustand → Riverpod `Notifier`로 대체합니다.

```dart
// 웹: Zustand store (onboarding)
// const { step, setStep } = useOnboardingStore();

// Flutter: Riverpod Notifier
@riverpod
class OnboardingState extends _$OnboardingState {
  @override
  OnboardingData build() => OnboardingData.initial();

  void setStep(int step) => state = state.copyWith(step: step);
  void setNickname(String name) => state = state.copyWith(nickname: name);
  void setJlptLevel(JlptLevel level) => state = state.copyWith(jlptLevel: level);
}
```

### 4.3 오프라인 캐시 설계

```
[네트워크 요청]
     │
     ├── 온라인 → API 호출 → 응답을 Drift 로컬 DB에 캐시 → UI 표시
     │
     └── 오프라인 → Drift 로컬 DB에서 캐시 데이터 읽기 → UI 표시
                     → 쓰기 작업은 큐에 저장 → 온라인 복귀 시 동기화
```

**캐시 대상:**

| 데이터 | 캐시 전략 | 이유 |
|--------|-----------|------|
| 단어/문법 데이터 | 적극 캐시 (1일 TTL) | 오프라인 학습 핵심 |
| 퀴즈 문제 | 세션 단위 캐시 | 퀴즈 중 네트워크 끊김 대응 |
| 가나 문자 데이터 | 영구 캐시 | 변경 없는 정적 데이터 |
| 학습 진도/통계 | 캐시 + 백그라운드 동기화 | 빠른 홈 화면 로딩 |
| AI 회화 | 캐시 안 함 | 온라인 필수 (AI API) |
| 유저 프로필 | 캐시 (로그인 시 갱신) | 기본 정보 오프라인 표시 |

**오프라인 쓰기 큐:**

```dart
// 퀴즈 답안 제출 — 오프라인이면 큐에 저장
Future<void> submitAnswer(QuizAnswer answer) async {
  if (await isOnline()) {
    await dio.post('/api/v1/quiz/answer', data: answer.toJson());
  } else {
    await localDb.pendingActions.insert(PendingAction(
      type: 'quiz_answer',
      payload: jsonEncode(answer.toJson()),
      createdAt: DateTime.now(),
    ));
  }
}

// 온라인 복귀 시 큐 처리
void onConnectivityRestored() async {
  final pending = await localDb.pendingActions.all();
  for (final action in pending) {
    await _processAction(action);
    await localDb.pendingActions.delete(action);
  }
}
```

### 4.4 인증 플로우

```
[앱 시작]
  → Supabase 세션 확인 (flutter_secure_storage에 저장됨)
  → 유효 → 홈 화면
  → 만료 → 자동 토큰 갱신 시도
  → 실패 → 로그인 화면

[API 호출]
  → Dio 인터셉터가 모든 요청에 Bearer 토큰 자동 첨부
  → 401 응답 → 토큰 갱신 → 재요청 (자동)
```

```dart
// Dio Auth 인터셉터
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      await Supabase.instance.client.auth.refreshSession();
      final retryResponse = await dio.fetch(err.requestOptions);
      handler.resolve(retryResponse);
      return;
    }
    handler.next(err);
  }
}
```

### 4.5 푸시 알림 설계

```
[서버] Next.js Cron (/api/cron/daily-reminder)
  → FCM 서버 SDK로 푸시 전송

[Flutter 앱]
  → firebase_messaging으로 FCM 토큰 수신
  → 토큰을 API에 등록 (POST /api/v1/push/subscribe)
  → 알림 수신 → flutter_local_notifications로 표시
  → 알림 탭 → GoRouter 딥링크로 해당 화면 이동
```

**기존 Web Push(VAPID) → FCM 전환:**
- `PushSubscription` 테이블에 `fcmToken` 필드 추가 (또는 별도 테이블)
- 서버 cron에서 Web Push + FCM 둘 다 발송 (웹 유저 + 앱 유저)

### 4.6 네비게이션 구조

```dart
GoRouter(
  initialLocation: '/home',
  redirect: (context, state) {
    final isLoggedIn = ref.read(authProvider).isLoggedIn;
    if (!isLoggedIn && !state.matchedLocation.startsWith('/login')) {
      return '/login';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),

    // 메인 (바텀 네비게이션)
    ShellRoute(
      builder: (_, __, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(path: '/study', builder: (_, __) => const StudyPage()),
        GoRoute(path: '/chat', builder: (_, __) => const ChatListPage()),
        GoRoute(path: '/stats', builder: (_, __) => const StatsPage()),
        GoRoute(path: '/my', builder: (_, __) => const MyPage()),
      ],
    ),

    // 서브 화면
    GoRoute(path: '/study/quiz', builder: (_, __) => const QuizPage()),
    GoRoute(path: '/study/result', builder: (_, __) => const ResultPage()),
    GoRoute(path: '/chat/:id', builder: (_, state) =>
      ChatRoomPage(id: state.pathParameters['id']!)),
  ],
);
```

### 4.7 테마 시스템

웹앱의 CSS Custom Properties → Flutter `ThemeData`로 매핑합니다.

```dart
class AppTheme {
  // 디자이너 확정 후 색상값 업데이트
  static ThemeData light() => ThemeData(
    colorScheme: const ColorScheme.light(
      primary: Color(0xFFF6A5B3),
      onPrimary: Colors.white,
      secondary: Color(0xFFFFF0F3),
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFFFCF6F5),
  );

  static ThemeData dark() => ThemeData(
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFF6A5B3),
      onPrimary: Colors.white,
      secondary: Color(0xFF2A2A4A),
      surface: Color(0xFF242442),
    ),
    scaffoldBackgroundColor: const Color(0xFF1A1A2E),
  );
}
```

---

## 5. 점진적 전환 순서

### Phase 0: 기반 세팅 (1~2주)

- [ ] Flutter 프로젝트 구조 재구성 (기존 WebView 코드 보존)
- [ ] 핵심 패키지 설치 및 설정 (Riverpod, Dio, Drift, GoRouter)
- [ ] Supabase Auth 연동 (로그인/회원가입)
- [ ] Dio 인터셉터 (인증 토큰, 에러 핸들링, 재시도)
- [ ] 테마 시스템 (Light/Dark)
- [ ] 바텀 네비게이션 셸
- [ ] FCM 푸시 알림 연동

### Phase 1: 핵심 학습 플로우 (2~4주)

안정적이고 잘 안 바뀌는 화면부터 네이티브로 구현합니다.

- [ ] 홈 화면 (대시보드, 스트릭, 오늘의 진도)
- [ ] 학습 탭 (레벨 선택, 학습 유형 카드)
- [ ] 퀴즈 (4지선다, 프로그레스 바, 결과 화면)
- [ ] 퀴즈 오프라인 캐시 (문제 로컬 저장, 답안 큐)
- [ ] 마이페이지 (프로필, 설정)

### Phase 2: 보조 기능 (2~3주)

- [ ] 가나 학습 (플래시카드, 매칭, 받아쓰기)
- [ ] 단어장
- [ ] 복습/통계
- [ ] 일일 미션
- [ ] 알림 센터

### Phase 3: AI 회화 (3~4주)

가장 복잡하고 실험적인 기능입니다.

- [ ] 채팅 목록/시나리오 선택
- [ ] 텍스트 채팅 (SSE 스트리밍)
- [ ] TTS 재생
- [ ] 음성 통화 (PCM 녹음 + WebSocket + Gemini Live)
- [ ] 피드백 화면

### Phase 4: 결제 + 마무리 (1~2주)

- [ ] 인앱 결제 (Apple IAP / Google Play Billing)
- [ ] 구독 상태 관리
- [ ] 웹 결제(PortOne)와의 구독 통합
- [ ] 스토어 업데이트 제출

---

## 6. 웹 ↔ Flutter 공존 전략

전환 기간 동안 미완성 화면은 WebView로 폴백합니다.

```dart
final nativeScreens = {'/home', '/study', '/study/quiz', '/my'};

GoRoute(
  path: '/:path(.*)',  // catch-all
  builder: (_, state) {
    if (nativeScreens.contains(state.matchedLocation)) {
      return getNativeScreen(state.matchedLocation);
    }
    return WebViewFallback(
      url: 'https://app.harukoto.co.kr${state.matchedLocation}',
    );
  },
);
```

---

## 7. API 호출 목록 (총 52개)

Flutter에서 호출해야 하는 기존 API 엔드포인트입니다. 백엔드 변경 없음.

### 인증 (2개)
- `POST /api/auth/ensure-user`
- `POST /api/v1/auth/onboarding`

### 퀴즈 (8개)
- `POST /api/v1/quiz/start` · `POST /api/v1/quiz/answer` · `POST /api/v1/quiz/complete`
- `GET /api/v1/quiz/resume` · `GET /api/v1/quiz/incomplete`
- `GET /api/v1/quiz/stats` · `GET /api/v1/quiz/wrong-answers` · `GET /api/v1/quiz/recommendations`

### 가나 학습 (7개)
- `GET /api/v1/kana/characters` · `GET /api/v1/kana/stages` · `GET /api/v1/kana/progress`
- `POST /api/v1/kana/quiz/start` · `POST /api/v1/kana/quiz/answer` · `POST /api/v1/kana/quiz/complete`
- `POST /api/v1/kana/stage-complete`

### AI 회화 (13개)
- `GET /api/v1/chat/characters` · `GET/POST /api/v1/chat/characters/favorites` · `GET /api/v1/chat/characters/stats`
- `GET /api/v1/chat/scenarios` · `POST /api/v1/chat/start` · `POST /api/v1/chat/message`
- `GET/DELETE /api/v1/chat/[conversationId]` · `GET /api/v1/chat/history` · `POST /api/v1/chat/end`
- `POST /api/v1/chat/tts` · `POST /api/v1/chat/live-feedback` · `POST /api/v1/chat/live-token`
- `POST /api/v1/chat/voice/transcribe`

### 대시보드/통계 (2개)
- `GET /api/v1/stats/dashboard` · `GET /api/v1/stats/history`

### 학습 (2개)
- `GET /api/v1/study/learned-words` · `GET /api/v1/study/wrong-answers`

### 미션 (2개)
- `GET /api/v1/missions/today` · `POST /api/v1/missions/claim`

### 단어장 (3개)
- `GET/POST /api/v1/wordbook` · `GET/DELETE /api/v1/wordbook/[id]`

### 알림/푸시 (2개)
- `GET /api/v1/notifications` · `POST /api/v1/push/subscribe`

### 유저 (3개)
- `GET/PATCH /api/v1/user/profile` · `POST /api/v1/user/avatar` · `DELETE /api/v1/user/account`

### 구독/결제 (6개)
- `GET /api/v1/subscription/status` · `POST /api/v1/subscription/checkout`
- `POST /api/v1/subscription/activate` · `POST /api/v1/subscription/cancel`
- `POST /api/v1/subscription/resume` · `POST /api/v1/payments`

### TTS (1개)
- `POST /api/v1/vocab/tts`

---

## 8. 데이터 모델 (Freezed)

웹앱의 TypeScript 타입 → Dart Freezed 클래스로 변환합니다.

```dart
@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    String? nickname,
    String? avatarUrl,
    required JlptLevel jlptLevel,
    required int dailyGoal,
    required int experiencePoints,
    required int level,
    required int streakCount,
    required bool isPremium,
    required bool onboardingCompleted,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

enum JlptLevel { N5, N4, N3, N2, N1 }
enum QuizType { VOCABULARY, GRAMMAR, KANJI, LISTENING, KANA, CLOZE, SENTENCE_ARRANGE }
enum KanaType { HIRAGANA, KATAKANA }
enum ConversationType { VOICE, TEXT }
```

---

## 9. 주의사항 및 리스크

### 9.1 결제 전환
- Apple/Google 스토어 정책상 **디지털 콘텐츠 구독은 인앱 결제 필수**
- 기존 PortOne 결제(카드/카카오페이)는 웹에서만 유지
- 앱에서는 IAP로 전환 → 수수료 30% 고려 필요
- 웹 구독과 앱 IAP 구독을 서버에서 통합 관리하는 로직 필요

### 9.2 Gemini Live 음성 통화
- 웹에서는 WebRTC/WebSocket + PCM 스트리밍으로 구현
- Flutter에서는 `record` + `web_socket_channel`로 대체
- 가장 복잡한 기능이므로 Phase 3에서 별도 시간 확보

### 9.3 딥링크
- 푸시 알림 탭 → 특정 화면으로 이동
- GoRouter의 딥링크 지원으로 처리
- Android App Links / iOS Universal Links 설정 필요

### 9.4 디자인 리뉴얼과의 타이밍
- Phase 0(기반 세팅)은 디자인 없이 진행 가능
- Phase 1부터는 디자이너 시안이 필요
- 디자이너 피드백 → 컬러/테마 확정 → Flutter ThemeData 반영

### 9.5 Supabase 모바일 약점 보완
- Supabase Flutter SDK는 오프라인 캐시를 내장하지 않음
- Drift(SQLite)로 로컬 캐시 계층을 직접 구현
- `connectivity_plus`로 온/오프라인 감지 → 자동 동기화
- Riverpod 3.0 자동 재시도로 네트워크 불안정 대응

---

## 10. 예상 일정

| Phase | 내용 | 예상 기간 | 디자인 의존성 |
|-------|------|-----------|---------------|
| Phase 0 | 기반 세팅 | 1~2주 | 없음 |
| Phase 1 | 핵심 학습 플로우 | 2~4주 | 디자이너 시안 필요 |
| Phase 2 | 보조 기능 | 2~3주 | Phase 1 시안 기반 확장 |
| Phase 3 | AI 회화 | 3~4주 | 보통 (실험적 UI) |
| Phase 4 | 결제 + 마무리 | 1~2주 | 없음 |
| **합계** | | **9~15주** | |

> AI(Claude) 활용 시 실제 개발 속도는 이보다 빠를 수 있습니다.

---

## 참고 자료

- [Flutter 3.41 Release](https://blog.flutter.dev/whats-new-in-flutter-3-41-302ec140e632)
- [Riverpod 3.0 공식 문서](https://riverpod.dev/)
- [Riverpod 3.0 What's New](https://riverpod.dev/docs/whats_new)
- [Supabase Flutter 문서](https://supabase.com/docs/reference/dart/upgrade-guide)
- [Drift 공식 문서](https://drift.simonbinder.eu/)
- [Supabase + Brick 오프라인 튜토리얼](https://supabase.com/blog/offline-first-flutter-apps)
- [Flutter State Management 2026](https://foresightmobile.com/blog/best-flutter-state-management)
