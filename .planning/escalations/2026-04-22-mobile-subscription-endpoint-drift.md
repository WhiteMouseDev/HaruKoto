---
raised_by: mobile-contract-validator
raised_at: 2026-04-22T14:00:00+09:00
phase: harness-setup
severity: blocker
status: open
---

## What happened

Phase 2.5의 모바일 드리프트 검증기 첫 실행 시 **실제 드리프트 1건** 발견:

- **파일:** `apps/mobile/lib/features/subscription/data/subscription_repository.dart:16`
- **모바일 호출:** `POST /api/v1/subscription/subscribe`
- **OpenAPI 현황:** 해당 엔드포인트 **없음**. 유사 엔드포인트는:
  - `POST /api/v1/subscription/checkout` — 결제 세션 시작
  - `POST /api/v1/subscription/activate` — 결제 후 활성화
  - `POST /api/v1/subscription/store/verify` — 스토어 영수증 검증

이 코드는 실제 호출 시 404를 받습니다. 현재 구독 기능이 모바일에서 작동 중인지 확인 필요.

## Decision required

어느 엔드포인트가 원래 의도인가? 다음 중 하나:

## Options considered

1. **`/subscription/checkout`로 교체** — PortOne 결제 세션 시작 (`CheckoutResponse` 반환). 가장 유력한 "구독 시작" 플로우
2. **`/subscription/store/verify`로 교체** — App Store / Play Store 영수증 검증. 스토어 구독 모델이면 이게 맞음
3. **백엔드에 `/subscription/subscribe` 추가** — 레거시 API 이름 복원
4. **조합 호출** — 실제 구독 플로우는 checkout → 결제 → activate. 현재 한 줄짜리 `subscribe()` 구현이 너무 단순한 것일 수도

## Recommended direction

**옵션 1 (`/subscription/checkout`) 가능성 높음.** 이유:
- 웹 admin/web은 PortOne 기반 결제 사용 중
- `CheckoutResponse` 스키마가 OpenAPI에 존재 (redirect URL 등 반환)
- 모바일도 동일 결제 플로우를 따를 가능성

다만 결정 전에 확인 필요:
- `subscribe(String planId)` 함수가 UI 어디서 호출되는지 (`grep "subscribe("` on `apps/mobile/lib/features/subscription/`)
- 실제 배포된 버전의 구독 플로우가 동작하는지 (QA 확인)

## Side effects

- 모바일 결제 UI 수정 필요 (checkout 응답의 redirect URL을 InAppWebView로 띄워야 함)
- `SubscriptionRepository.subscribe()` 시그니처 변경 가능성
- 기존 사용자 중 이 메서드 호출했던 사람 있으면 에러 로그 확인

## Resolution path

결정 내려지면 `mobile-agent`에게 위임:
1. `subscription_repository.dart` 수정
2. Dart 모델(`CheckoutResponse` 미러링) 정의/업데이트
3. UI 계층에서 redirect URL 처리
4. 테스트 추가 또는 갱신
