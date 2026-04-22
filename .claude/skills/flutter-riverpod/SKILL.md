---
name: flutter-riverpod
description: Flutter/Dart/Riverpod 3.x conventions, iOS device IDs, sheet stabilization rules, build commands for apps/mobile. Use when editing anything under apps/mobile.
---

# Mobile (Flutter) Skill

`apps/mobile` 전용 Flutter 패턴.

## 빌드 (중요)

- **모든 빌드/실행 시 반드시 `--dart-define-from-file=.env` 포함**
  (누락 시 Supabase 등 환경 변수 미로드로 앱 동작 불가)
- **`flutter run` 우선**. `flutter build` 후 `simctl install`로 재설치하면 로그인 세션이 날아감
- 실기기 device ID: `00008150-000A20881E88401C` (Kun Woo's iPhone)
- 시뮬레이터: `iPhone 17 Pro` (ID: `16FEF8B7-DC41-49D8-9EC6-E9911468E875`)

### 자주 쓰는 커맨드
```bash
# Release 빌드
flutter build ios --release --dart-define-from-file=.env

# 실기기 설치
flutter install --release -d 00008150-000A20881E88401C

# Debug 실기기
flutter run -d 00008150-000A20881E88401C --dart-define-from-file=.env

# 시뮬레이터
flutter run -d 16FEF8B7-DC41-49D8-9EC6-E9911468E875 --dart-define-from-file=.env

# 시뮬레이터 빌드 확인
flutter build ios --simulator --no-tree-shake-icons --dart-define-from-file=.env
```

## 시트 안정화 규칙 (핵심)

- BottomSheet/Modal은 **결과만 반환** (`Navigator.pop(result)`)
- API 호출 / 상태 변경(`ref.invalidate` 포함)은 `await showModalBottomSheet(...)` **이후 부모에서** 처리
- TextField + 키보드 시트 패턴:
  - `useRootNavigator: true`
  - 시트 내부는 `StatefulWidget` 분리
  - `MediaQuery.viewInsetsOf(context)` 로 키보드 인셋 반영

## 아키텍처

- **Riverpod 3.x**: `features/{feature}/providers/`
- **Repository 패턴**: `features/{feature}/data/{feature}_repository.dart`
- **Feature-first 구조**: `features/{feature}/{data,providers,presentation}/`
- 코어: `lib/core/` (auth, constants, network, router, services, settings, theme)
- 공유 위젯: `lib/shared/`

## API 소비

- Dio 인증 인터셉터(`lib/core/network/`) **재사용**. 직접 `http` 호출 금지
- 응답 타입은 `features/{feature}/data/models/`에 Dart 모델로 미러링
- 한국어 에러 메시지는 `ApiException.userMessage`를 통해서만

## Lint

- 커밋 전:
  ```bash
  cd apps/mobile && dart format --set-exit-if-changed lib/ test/
  cd apps/mobile && flutter analyze
  cd apps/mobile && flutter test
  ```
- 에러 시 커밋 차단
- 주요 enforced rules: `avoid_print`, `cancel_subscriptions`, `close_sinks`,
  `unawaited_futures`, `prefer_const_constructors`, `prefer_final_locals`,
  `prefer_single_quotes`, `always_declare_return_types`, `avoid_dynamic_calls`

## 인증

- Supabase 세션은 `lib/core/auth/` 를 통해서만 관리
- 직접 토큰 저장/조회 금지
