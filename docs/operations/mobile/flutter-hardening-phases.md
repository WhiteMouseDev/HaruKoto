# Flutter Hardening Phases

Phase 1-1 구현 완료 후, 프로덕션 릴리스를 위한 품질 강화 작업.

---

## Phase 2-1: Security (즉시)

### 2-1-A: AuthInterceptor 토큰 리프레시 락

**현재 문제:**
- 동시 401 응답 시 race condition (여러 요청이 동시에 refreshSession 호출)
- `Dio()` 새 인스턴스가 인터셉터 우회 (무한 루프 방지 의도이지만 인터셉터 누락)

**조치:**
- `Completer` 기반 토큰 리프레시 락 구현
- 리프레시 중 다른 401 요청은 대기 후 재시도
- 리프레시 전용 Dio 인스턴스에 baseUrl/timeout만 설정

**파일:** `lib/core/network/auth_interceptor.dart`

### 2-1-B: flutter_secure_storage 토큰 저장

**현재 문제:**
- pubspec에 `flutter_secure_storage: ^9.2.0` 있으나 import 0회
- Supabase SDK 자체 토큰 관리에 의존 중

**조치:**
- Supabase 세션 토큰을 SecureStorage에 백업 저장
- 앱 재시작 시 SecureStorage에서 복원 시도
- `SecureStorageService` 래퍼 클래스 생성

**파일:** `lib/core/storage/secure_storage_service.dart`

---

## Phase 2-2: CI/CD (높음)

### Flutter CI 파이프라인

**현재 상태:** `.github/workflows/ci.yml`에 Frontend(Next.js) + Backend(FastAPI)만 존재

**조치:**
- `ci.yml`에 Flutter Mobile job 추가
- `flutter analyze` (lint 검증)
- `flutter test` (단위 테스트)
- Android build 검증 (`flutter build apk --debug`)

**파일:** `.github/workflows/ci.yml`

---

## Phase 2-3: Testing (높음)

### 핵심 Model/Repository 단위 테스트

**현재 상태:** smoke test 1개 (실질 의미 없음)

**조치:**
- Data Model `fromJson` 테스트 (null-safe 파싱 검증)
  - `dashboard_model_test.dart`
  - `mission_model_test.dart`
  - `user_profile_model_test.dart`
- Repository 테스트 (Dio mock)
- Provider 테스트 (ProviderContainer override)

**대상 모델:** home, study, kana, chat, stats, my, subscription (7 feature)

---

## Phase 2-4: Monitoring (중간)

### Sentry 연동

**현재 상태:** 크래시 리포팅 0. 백엔드에만 `SENTRY_DSN` 존재.

**조치:**
- `sentry_flutter` 패키지 추가
- `main.dart`에서 SentryFlutter.init 래핑
- ErrorInterceptor에서 Sentry.captureException 호출
- 환경별 DSN 분리 (dart-define)

**파일:** `pubspec.yaml`, `lib/main.dart`, `lib/core/network/error_interceptor.dart`

---

## Phase 2-5: 하드코딩 색상 통합 (중간)

### 시맨틱 색상 체계 확장

**현재 상태:** 41개 파일에서 `Colors.*` 직접 사용 (120+ 인스턴스)

**조치:**
1. `AppColors`에 시맨틱 색상 추가:
   - `success` (Colors.green 대체)
   - `error` / `destructive` (Colors.red 대체)
   - `warning` (Colors.amber/orange 대체)
   - `info` (Colors.blue 대체)
   - `onGradient` (gradient 위 흰색 텍스트)
   - `overlay` (Colors.black.withAlpha 대체)
2. 41개 파일의 하드코딩 색상을 `AppColors.*` 또는 `theme.colorScheme.*`로 교체

**파일:** `lib/core/constants/colors.dart` + 41개 feature 파일

---

## 우선순위 요약

| Phase | 영역 | 긴급도 | 예상 규모 |
|-------|------|--------|----------|
| 2-1 | Security | 즉시 | 2 파일 신규/수정 |
| 2-2 | CI/CD | 높음 | 1 파일 수정 |
| 2-3 | Testing | 높음 | 10+ 테스트 파일 |
| 2-4 | Monitoring | 중간 | 3 파일 수정 |
| 2-5 | Colors | 중간 | 42 파일 수정 |

---

## 제외 사항

- **`.env` git history 제거**: 조사 결과 `.env`는 `.gitignore`에 포함되어 있으며, git history에 커밋된 적 없음. 조치 불필요.
- **접근성(Semantics)**: 별도 Phase에서 전체 스크린 대상으로 진행
- **i18n**: 한국어 단일 지원으로 현재 불필요. 다국어 확장 시 별도 Phase
