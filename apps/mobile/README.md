# HaruKoto Mobile (하루코토)

한국인을 위한 일본어 학습 Flutter 앱.

## Tech Stack

- Flutter 3.6+ / Dart 3.6+
- Riverpod (State Management)
- Dio (HTTP Client)
- GoRouter (Navigation)
- Supabase (Auth)
- Sentry (Error Monitoring)

## Getting Started

```bash
# Install dependencies
flutter pub get

# Run with environment variables
flutter run \
  --dart-define=SUPABASE_URL=your-url \
  --dart-define=SUPABASE_ANON_KEY=your-key \
  --dart-define=API_BASE_URL=your-api-url

# Run analysis
flutter analyze

# Run tests
flutter test
```

## Widgetbook (컴포넌트 카탈로그)

Storybook처럼 위젯을 개별 상태로 확인하려면 Widgetbook 엔트리로 실행합니다.

```bash
# iOS/Android 에뮬레이터에서 실행
flutter run -t lib/widgetbook.dart

# 웹(Chrome)에서 실행
flutter run -d chrome -t lib/widgetbook.dart
```

현재 등록된 카탈로그는 다음 폴더를 포함합니다.
- `Shared`: `AppCard`, `AppErrorRetry`, `AppSkeleton`, `BottomNav`
- `Home`: `HomeHeader`
- `Study`: `TabSwitcher`, `QuizProgressBar`

### 새 컴포넌트 추가 방법

1. `lib/widgetbook.dart`의 `directories`에 `WidgetbookComponent`를 추가합니다.
2. 상태가 필요한 경우 `WidgetbookUseCase`에서 `context.knobs`로 조절값을 노출합니다.
3. 앱 테마 확인은 좌측 상단 Theme Addon에서 `Light/Dark`를 전환해 검증합니다.

## Project Structure

```
lib/
├── core/           # App infrastructure (theme, network, routing, constants)
├── features/       # Feature modules (home, study, kana, chat, stats, my, auth, subscription, legal)
├── shared/         # Shared widgets and models
└── legacy/         # WebView fallback
```

## Architecture

Feature-based architecture with data/providers/presentation layers per module.
See `RULES.md` for detailed conventions.
