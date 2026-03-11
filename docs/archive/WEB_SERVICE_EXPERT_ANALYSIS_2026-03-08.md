# /apps/web 서비스 정밀 분석 리포트 (2026-03-08)

## 1. 분석 목적과 범위

이 문서는 모노레포 내 `/apps/web` 서비스의 현재 구현을 기준으로, 다음 3개 관점에서 실무형 평가를 제공합니다.

1. 코드/아키텍처 관점
2. UI/UX 관점
3. 비즈니스 모델/수익화 관점

분석 기준은 실제 코드(`apps/web/src`), 데이터 모델(`packages/database/prisma/schema.prisma`), 결제/구독 로직, 테스트 결과(`pnpm --filter web test`)입니다.

## 2. 서비스 개요 (현재 구현 기준)

### 2.1 제품 성격

- 모바일 퍼스트 일본어 학습 앱 (PWA + Flutter WebView 연동)
- 핵심 도메인: JLPT 학습(단어/문법/가나), AI 텍스트 회화, AI 음성 통화, 구독 결제

### 2.2 구조 요약

- 프레임워크: Next.js 16 App Router
- 인증/DB: Supabase Auth + Prisma(PostgreSQL)
- 상태 관리: TanStack Query + 일부 Zustand
- 결제: PortOne V2 (구독/웹훅/정기갱신 크론)
- AI: Google/OpenAI Provider 추상화 + Gemini Live 토큰
- 운영성: Sentry/GA/Push 알림/PWA service worker

### 2.3 코드 규모 체감 지표

- API Route 파일: 54개
- Feature 컴포넌트: 56개
- 커스텀 훅: 26개
- 테스트 파일: 9개

## 3. 코드 레벨 평가

## 3.1 강점

1. 도메인 경계가 비교적 명확합니다.
   - 학습/회화/통계/구독/결제가 `app/api/v1/*` 기준으로 분리됨
2. DB 스키마가 제품 기능을 잘 반영합니다.
   - 학습 진도(SRS), 회화, 구독/결제, 가나 학습, 업적까지 일관된 모델링
3. 캐시 무효화 전략이 실제 사용자 액션에 맞춰 설계되어 있습니다.
   - 퀴즈 완료 후 대시보드/프로필/알림 invalidate
4. 온보딩-학습-회화-리포트 흐름이 코드상 연결되어 있습니다.
5. 결제 웹훅에 시그니처 검증과 timestamp 검증이 들어가 있습니다.

## 3.2 핵심 리스크 (우선순위 높음)

### P0급 (즉시 수정 권장)

1. 퀴즈 완료 API가 멱등하지 않습니다.
   - 파일: `apps/web/src/app/api/v1/quiz/complete/route.ts`
   - `completedAt` 여부 검사 없이 XP/통계/레벨을 누적 갱신합니다.
   - 동일 `sessionId` 재호출로 XP를 반복 획득할 수 있습니다.

2. 결제 활성화 API가 결제 레코드 상태를 강제 검증하지 않습니다.
   - 파일: `apps/web/src/app/api/v1/subscription/activate/route.ts`
   - `activateSubscription()` 내부에서 구독 생성이 먼저 실행됩니다.
   - `payment(PENDING -> PAID)` 업데이트가 0건이어도 구독이 생성될 수 있습니다.
   - 결제 ID 재사용/오용 시 구독 무결성 훼손 가능성이 큽니다.

3. 퀴즈 답안 API 스키마와 UI 모드가 불일치합니다.
   - 파일: `apps/web/src/app/api/v1/quiz/answer/route.ts`
   - `questionType` 허용값이 `VOCABULARY | GRAMMAR`만 허용됩니다.
   - 반면 UI는 `CLOZE`, `SENTENCE_ARRANGE`를 전송합니다.
   - 결과적으로 일부 모드에서 정오답 기록/SRS 반영이 실패할 수 있습니다.

4. AI 통화 사용량 추적이 누락되어 무료 제한이 실질적으로 약합니다.
   - 파일: `apps/web/src/lib/subscription-service.ts`, `apps/web/src/app/api/v1/chat/live-feedback/route.ts`
   - `checkAiLimit('call')`은 있으나 `trackAiUsage('call', ...)` 호출이 보이지 않습니다.
   - 무료 제한 정책(`CALL_COUNT`, `CALL_SECONDS`)이 의도대로 작동하지 않을 가능성이 높습니다.

### P1급 (빠른 시일 내 개선 권장)

1. 인메모리 Rate Limit은 멀티 인스턴스 환경에서 일관성이 약합니다.
   - 파일: `apps/web/src/lib/rate-limit.ts`
   - 서버리스 수평 확장 환경에서 사용자 단위 제어가 약화됩니다.

2. 미션 보상을 GET에서 자동 지급하는 구조는 동시성에 취약합니다.
   - 파일: `apps/web/src/app/api/v1/missions/today/route.ts`
   - 동시 호출 시 중복 지급 가능성이 존재합니다.

3. 모드별 재개(resume) 처리가 불완전합니다.
   - 파일: `apps/web/src/app/(app)/study/quiz/page.tsx`
   - `typing`/`matching` 세션 재개 시 모드 복원이 안정적이지 않습니다.

4. 테스트 실패가 존재합니다.
   - 실행 결과: 118개 중 7개 실패
   - 실패 파일: `gamification.test.ts`, `stats-components.test.tsx`
   - 회귀 안정성 신뢰도를 떨어뜨립니다.

## 3.3 품질/운영성 평가

### 관찰 사항

1. 클라이언트 공통 fetch wrapper(`apiFetch`)는 단순하고 일관적입니다.
2. 다만 대규모 API 레이어 대비 통합 테스트/E2E 테스트가 부족합니다.
3. 결제/구독/AI 사용량과 같은 고위험 영역은 시나리오 테스트가 필요합니다.
4. PWA 서비스워커는 최소 구현 수준이며 오프라인 전략이 제한적입니다.
5. 일부 정적 자산 참조 불일치가 있습니다.
   - `sw.js`에서 `badge: /icons/icon-72x72.svg` 사용, 실제 파일 없음

## 3.4 기술 부채 성격

현재 상태는 "기능 확장 속도는 빠르지만, 정합성/멱등성/운영 테스트가 뒤따르지 못한 상태"로 분류됩니다.  
즉, 제품 매력은 충분하지만 수익화/운영 규모가 커질수록 결함 비용이 급격히 증가할 구조입니다.

## 4. UI/UX 평가

## 4.1 강점

1. 모바일 퍼스트 정보 구조가 명확합니다.
   - 하단 네비게이션 + 탭 구조 + 카드형 정보 전달
2. 온보딩 경험이 짧고 결정적입니다.
   - 닉네임 → JLPT → 목표(및 N5 가나 분기)
3. 학습 피드백 루프가 풍부합니다.
   - 결과 화면의 정답률/XP/오답/다음 추천 CTA
4. 회화 UX가 텍스트/음성으로 분기되어 진입점이 다양합니다.
5. 로딩/에러/스켈레톤이 주요 화면에 광범위하게 적용되어 있습니다.

## 4.2 UX 리스크

1. 접근성 측면에서 확대 제한이 강합니다.
   - `viewport.userScalable = false`
   - 저시력 사용자 접근성 저하 우려

2. 애니메이션 의존도가 높아 저사양 디바이스에서 체감 지연 가능성이 있습니다.
   - 대시보드/학습/회화 대부분 Framer Motion 다중 적용

3. 일부 흐름은 기능은 있지만 사용자 기대와 불일치합니다.
   - 고급 퀴즈 모드(클로즈/어순/타이핑)의 재개/오답복습 연계가 매끄럽지 않음

4. 에러 메시지 언어/톤이 API별로 조금씩 다릅니다.
   - 사용자 관점에서는 "왜 실패했는지" 일관되게 이해하기 어렵습니다.

## 4.3 UI 일관성

1. 봄톤(핑크 기반) 테마 일관성은 좋습니다.
2. 아이콘/라벨링/카드 컴포넌트 사용도 안정적입니다.
3. 다만 문서(PRD)와 실제 가격/제한 수치가 다르므로, UX 카피 일관성 관리가 필요합니다.

## 5. 비즈니스 모델 평가

## 5.1 현재 구현된 모델

### Free

- JLPT 학습/퀴즈/통계/가나: 사실상 무료 핵심
- AI 제한: 채팅 3회/300초, 통화 1회/180초 (코드 기준)

### Premium

- AI 무제한 + 캐릭터 확장 + 구독 관리
- 가격: 월 4,900원 / 연 39,900원 (코드 기준)

## 5.2 모델 강점

1. 무료 코어 학습 가치가 충분해 상단 퍼널 유입에 유리합니다.
2. 유료 전환 포인트(AI 사용량 제한)가 명확합니다.
3. 결제 플로우(Checkout -> Activate -> Webhook -> Renewal)가 구체적으로 구현되어 있습니다.
4. 법적 신뢰 요소(약관/개인정보/사업자 정보)가 서비스 내에 노출됩니다.

## 5.3 모델 리스크

1. 수익화 핵심인 AI 제한 정책의 집행 강도가 약합니다.
   - 통화 사용량 추적 누락 가능성
   - 채팅 종료 기반 집계는 우회 여지가 큼

2. 결제 활성화 멱등성/검증 누수는 수익 손실 리스크로 직결됩니다.

3. 문서-코드 불일치가 존재합니다.
   - PRD/일부 문서 대비 가격, 무료 제한 수치가 다릅니다.
   - 운영/마케팅/CS 메시지 혼선 위험이 있습니다.

4. N3~N1 실제 학습 콘텐츠 노출 전략이 아직 제한적입니다.
   - 성장 후반(고레벨 학습자) 리텐션 확장이 느릴 수 있습니다.

## 5.4 KPI 관점 제언

실행/모니터링 추천 KPI:

1. 무료 -> 유료 전환율 (AI 제한 도달 사용자 기준)
2. AI 제한 도달 후 24시간 내 결제 전환율
3. 결제 성공 대비 활성화 성공률 (Activate/Webhook 분리 추적)
4. 통화 세션당 평균 길이, 종료율, 피드백 생성 성공률
5. 학습 모드별 완료율 (normal/matching/cloze/arrange/typing)

## 6. 우선순위 개선 로드맵

## 6.1 2주 이내 (P0)

1. `quiz/complete`, `kana/quiz/complete` 멱등성 보장
2. `subscription/activate`에 결제 레코드 상태 강제 검증 + idempotency 보강
3. `quiz/answer` 스키마와 고급 모드(questionType) 정합성 복구
4. `trackAiUsage('call')` 경로 정리 + 무료 제한 E2E 검증
5. 실패 테스트 7건 정리 후 CI에서 gate 적용

## 6.2 6주 이내 (P1)

1. Rate limit Redis/Upstash 등 외부 저장소 기반으로 전환
2. 미션 보상 지급 경로 단일화(GET 자동지급 제거 또는 claim API 일원화)
3. 결제/구독/AI 사용량 시나리오 테스트 추가
4. 퀴즈 고급 모드의 재개/오답복습 UX 일관화

## 6.3 분기 단위 (P2)

1. 문서(PRD/정책/가격)와 코드 상수 싱크 체계 구축
2. 제품 분석 이벤트 표준화(학습/회화/결제 퍼널 공통 이벤트)
3. 접근성 개선(확대 허용, reduced motion, 스크린리더 보강)

## 7. 최종 평가

현재 `/apps/web`는 "제품 매력도와 기능 밀도는 높은 편"입니다.  
다만 **수익화 안정성(결제/AI 제한)과 데이터 정합성(퀴즈/보상/멱등성)**이 운영 규모 대비 취약합니다.

요약하면:

1. 서비스 방향성: 좋음
2. 기능 완성도: 높음
3. 운영 안정성: 보강 필요
4. 수익화 내구성: 핵심 리스크 존재

즉, 지금 단계의 최적 전략은 "기능 추가"보다 "정합성/결제/제한 정책의 신뢰도 강화"입니다.

## 8. 근거 파일 (핵심)

- `apps/web/src/app/api/v1/quiz/complete/route.ts`
- `apps/web/src/app/api/v1/quiz/answer/route.ts`
- `apps/web/src/app/api/v1/subscription/activate/route.ts`
- `apps/web/src/lib/subscription-service.ts`
- `apps/web/src/app/api/v1/chat/live-token/route.ts`
- `apps/web/src/app/api/v1/chat/live-feedback/route.ts`
- `apps/web/src/app/(app)/study/quiz/page.tsx`
- `apps/web/src/app/(app)/chat/page.tsx`
- `apps/web/src/app/(app)/subscription/checkout/page.tsx`
- `apps/web/src/lib/rate-limit.ts`
- `apps/web/public/sw.js`
- `packages/database/prisma/schema.prisma`

