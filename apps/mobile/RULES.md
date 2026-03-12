# HaruKoto Flutter App Rules

이 프로젝트(하루코토 모바일 앱)에 특화된 Flutter/Dart 개발 규칙.

## 프로젝트 구조

Feature-based 아키텍처를 따른다.

```
lib/
├── main.dart
├── app.dart
├── core/                          # 앱 전역 인프라
│   ├── constants/                 # AppColors, AppSizes, AppConfig
│   ├── network/                   # Dio 클라이언트, 인터셉터, ApiException
│   ├── router/                    # GoRouter 설정
│   └── theme/                     # Material 3 테마, 텍스트 테마
├── features/                      # 기능 모듈 (각각 독립적)
│   └── {feature}/
│       ├── data/
│       │   ├── models/            # 데이터 모델 (fromJson)
│       │   └── {feature}_repository.dart
│       ├── providers/
│       │   └── {feature}_provider.dart
│       └── presentation/
│           ├── {feature}_page.dart
│           └── widgets/           # 페이지 전용 위젯
├── shared/
│   ├── models/                    # 공유 모델
│   └── widgets/                   # 공유 위젯 (MainShell, BottomNav)
└── legacy/                        # WebView 레거시
```

새 기능 추가 시 반드시 이 구조를 따른다. 파일은 `snake_case.dart`.

## 핵심 기술 스택

- **State Management:** Riverpod (`flutter_riverpod`)
- **HTTP:** Dio (AuthInterceptor + ErrorInterceptor)
- **Routing:** GoRouter (StatefulShellRoute + bottom nav)
- **Auth:** Supabase Flutter
- **Icons:** `lucide_icons` (Material Icons 사용 금지)
- **Fonts:** Google Fonts (Noto Sans JP)
- **Theme:** Material 3 + 커스텀 ColorScheme

## State Management — Riverpod

Riverpod을 사용한다. Flutter 내장 상태 관리(ChangeNotifier, ValueNotifier, Provider 패키지)를 사용하지 않는다.

### Provider 패턴

```dart
// 서버 데이터: FutureProvider.autoDispose
final dashboardProvider = FutureProvider.autoDispose<DashboardModel>((ref) {
  return ref.watch(homeRepositoryProvider).fetchDashboard();
});

// 실시간 스트림: StreamProvider
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// 싱글턴 서비스: Provider
final homeRepositoryProvider = Provider((ref) {
  return HomeRepository(ref.watch(dioProvider));
});

// 로컬 상태: StateNotifier + StateNotifierProvider
final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier();
});
```

### 위젯에서 사용

```dart
// ConsumerWidget 또는 ConsumerStatefulWidget 사용
class HomePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(dashboardProvider);

    return asyncData.when(
      loading: () => const LoadingSkeleton(),
      error: (e, _) => ErrorRetry(onRetry: () => ref.invalidate(dashboardProvider)),
      data: (dashboard) => DashboardView(dashboard: dashboard),
    );
  }
}
```

### 규칙

- 서버 데이터는 `FutureProvider.autoDispose`로 자동 해제
- `ref.invalidate()`로 데이터 새로고침 (pull-to-refresh)
- Dio 인스턴스는 `dioProvider`를 공유 (home_provider.dart에 정의)
- Repository는 생성자에서 Dio를 주입받음

## 데이터 모델 & JSON

수동 `fromJson` 팩토리 메서드를 사용한다. `json_serializable`을 사용하지 않는다.

```dart
class UserProfileModel {
  final String nickname;
  final int dailyGoal;
  final bool showKana;

  const UserProfileModel({
    required this.nickname,
    required this.dailyGoal,
    required this.showKana,
  });

  // null-safe 파싱, 기본값 제공
  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      nickname: json['nickname'] as String? ?? '학습자',
      dailyGoal: json['dailyGoal'] as int? ?? 10,
      showKana: json['showKana'] as bool? ?? true,
    );
  }
}
```

### 규칙

- 모든 필드에 `as Type?` 캐스팅 + `?? 기본값`으로 null-safe 파싱
- `const` 생성자 사용
- 계산 프로퍼티는 getter로 (예: `double get progress => ...`)
- `toJson`은 필요할 때만 구현

## Repository 패턴

```dart
class HomeRepository {
  final Dio _dio;

  HomeRepository(this._dio);

  Future<DashboardModel> fetchDashboard() async {
    final response = await _dio.get<Map<String, dynamic>>('/stats/dashboard');
    return DashboardModel.fromJson(response.data!);
  }
}
```

- Dio baseUrl이 이미 `/api/v1`을 포함하므로 경로는 `/stats/dashboard` 형태
- 에러 처리는 Dio 인터셉터(ErrorInterceptor)에서 `ApiException`으로 변환
- Repository에서 try-catch 하지 않음 — Provider의 `.when(error:)`에서 처리

## 라우팅 — GoRouter

### 구조

- `StatefulShellRoute.indexedStack`: 하단 탭 네비게이션 (Home, Stats, Study, Chat, My)
- 탭 내부 서브 페이지: GoRoute의 `routes` 중첩
- 전체 화면 (모달): `parentNavigatorKey: _rootNavigatorKey`
- 인증 리다이렉트: `redirect` 콜백에서 `isAuthenticatedProvider` 확인

### 네비게이션 사용

```dart
// 탭 간 이동
context.go('/study');

// 서브 페이지 push
context.go('/study/kana/hiragana/stage/1');

// GoRouter 밖의 전체 화면 (퀴즈, 음성통화 등)
Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizPage()));
```

- `context.go()`: 탭 기반 라우트
- `context.push()`: 스택에 쌓기
- `Navigator.push()`: GoRouter 밖 전체 화면 (딥링크 불필요한 경우)

## 테마 & 스타일링

### 색상 체계

`AppColors`에 정의된 브랜드 색상을 사용한다. `ColorScheme.fromSeed()`를 사용하지 않는다.

```dart
// 브랜드 색상
AppColors.primary          // #F6A5B3 (핑크)
AppColors.brandPink        // #FFB7C5

// 시맨틱 색상 (brightness 인자)
AppColors.hkBlue(brightness)   // #87CEEB / #5BA3C9
AppColors.hkYellow(brightness) // #FFD93D / #E5C235
AppColors.hkRed(brightness)    // #FF6B6B / #E05252
```

### 테마 사용

```dart
final theme = Theme.of(context);

// 색상
theme.colorScheme.primary
theme.colorScheme.surfaceContainerLowest  // 카드 배경
theme.colorScheme.secondary              // 연한 배경
theme.colorScheme.outline                // 테두리

// 텍스트
theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)

// 스페이싱
AppSizes.sm   // 8
AppSizes.md   // 16
AppSizes.lg   // 24
AppSizes.cardRadius  // 24
```

### 카드 스타일 패턴

```dart
Container(
  decoration: BoxDecoration(
    color: theme.colorScheme.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(AppSizes.cardRadius),
    border: Border.all(color: theme.colorScheme.outline),
  ),
  padding: const EdgeInsets.all(20),
  child: ...,
)
```

### Gradient CTA 패턴

```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [
        theme.colorScheme.primary,
        theme.colorScheme.primary.withValues(alpha: 0.8),
      ],
    ),
    borderRadius: BorderRadius.circular(AppSizes.cardRadius),
  ),
  child: Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      onTap: () { ... },
      child: ...,
    ),
  ),
)
```

## Dart 코드 스타일

### 네이밍

- 클래스: `PascalCase` (`UserProfileModel`)
- 변수/함수: `camelCase` (`fetchDashboard`)
- 파일: `snake_case` (`user_profile_model.dart`)
- 상수: `camelCase` (Dart 컨벤션, UPPER_SNAKE_CASE 아님)

### 코드 규칙

- 줄 길이: **120자** 이내
- `const` 생성자를 적극 사용
- `any` 타입 사용 금지
- `!` 연산자는 값이 보장될 때만 사용 (예: `response.data!`)
- `switch` 표현식 선호 (`switch (type) { 'a' => ..., _ => ... }`)
- 화살표 함수: 한 줄이면 `=>` 사용
- `async`/`await` 사용, `.then()` 체이닝 지양

### Private 위젯

`build()` 메서드에서 헬퍼 메서드 대신 private Widget 클래스를 추출한다.

```dart
// 좋음
class _StatTile extends StatelessWidget { ... }

// 나쁨
Widget _buildStatTile() { ... }
```

## 위젯 작성 규칙

### 기본 원칙

- `StatelessWidget` 기본, 상태 필요 시 `StatefulWidget`
- Riverpod 사용 시 `ConsumerWidget` / `ConsumerStatefulWidget`
- 리스트는 `ListView.builder` 또는 `SliverList` 사용
- `const` 위젯은 `const`로 인스턴스화
- `build()` 안에서 네트워크 호출이나 복잡한 계산 금지

### 아이콘

`lucide_icons` 패키지만 사용한다.

```dart
import 'package:lucide_icons/lucide_icons.dart';

Icon(LucideIcons.bookOpen, size: 20)
```

### 네트워크 이미지

```dart
Image.network(
  url,
  loadingBuilder: (context, child, progress) {
    if (progress == null) return child;
    return const Center(child: CircularProgressIndicator());
  },
  errorBuilder: (context, error, stackTrace) {
    return const Icon(Icons.error);
  },
)
```

## 에러 처리

- API 에러는 Dio `ErrorInterceptor`가 `ApiException`으로 변환
- UI에서는 Riverpod `.when(error:)`로 에러 화면 표시
- 재시도: `ref.invalidate(provider)`
- Pull-to-refresh: `RefreshIndicator` + `ref.invalidate()`

## 레이아웃

- `Expanded`: 남은 공간 채우기
- `Flexible`: 축소 허용
- `Wrap`: 줄바꿈 필요 시
- `ListView.builder`: 긴 리스트
- `LayoutBuilder`: 반응형 레이아웃
- `SafeArea`: 노치/홈 인디케이터 대응
- `Stack` + `Positioned`: 겹치기 레이아웃

## 테스트

- **단위 테스트:** `package:flutter_test`, Repository와 Model 위주
- **위젯 테스트:** 주요 페이지와 인터랙티브 위젯
- **통합 테스트:** `package:integration_test`로 핵심 플로우
- **패턴:** Arrange-Act-Assert
- **모킹:** `mocktail` 사용, Riverpod `ProviderContainer` 오버라이드

## 접근성

- 텍스트 대비: 최소 4.5:1 (WCAG 2.1)
- `Semantics` 위젯으로 스크린 리더 라벨 제공
- 동적 폰트 크기 대응 테스트
- 터치 타겟: 최소 48x48 dp

## 패키지 관리

- 새 패키지 추가 전 기존 의존성으로 해결 가능한지 확인
- `flutter pub add <package>`로 추가
- `flutter analyze` 통과 필수
- 사용하지 않는 패키지는 즉시 제거

## 코멘트 & 문서화

- 코드가 스스로 설명되면 코멘트 불필요
- "왜"를 설명하는 코멘트만 작성 ("무엇"은 코드가 말함)
- 모든 public API에 dartdoc 강제하지 않음 — 복잡한 로직에만
- TODO는 구체적으로: `// TODO: {무엇을} {왜}`
