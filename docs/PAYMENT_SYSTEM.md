# 결제/구독 시스템 설계 문서

> PG: PortOne (포트원) V2 — TossPayments에서 전환 (2026-03)

> **상태**: 설계 완료 / 구현 완료
> **최종 업데이트**: 2026-03-05
> **대상 시장**: 한국 (KR)

---

## 0. 단계별 출시 전략

> **핵심**: 결제 시스템은 유저 확보 후 도입한다.

### 현재 단계 — 무료 런칭 (결제 없음)

초기에는 결제 시스템 없이 런칭하는 전략을 취했으나,
전환 트리거 충족 후 PortOne V2 기반으로 구현을 완료하였다.

**지금 구현할 것:**
- AI 회화 **하루 채팅 3회/5분, 통화 1회/3분 제한**을 서버에서 적용 (DailyAiUsage 모델 + 체크 로직)
- 무료 사용자에게 남은 횟수/시간 표시 UI
- 프리미엄/결제 관련 UI는 **노출하지 않음**

**지금 구현하지 않을 것:**
- 구독/결제 UI (Pricing 페이지 포함)
- 프로필 내 구독 관리

### 전환 트리거 — 결제 도입 시점

다음 조건 중 하나라도 충족되면 결제 시스템 구현을 시작한다:

1. **MAU 500+ 도달** — 유료 전환 가능한 최소 모수
2. **AI 30분 제한 도달 유저 비율 20%+** — 실제 유료 수요 확인
3. **유저 피드백에서 유료 의향 다수 확인** — 설문/인앱 피드백

전환 시 Phase 1 → 2 → 3 → 4 순서로 구현한다 (아래 9장 로드맵 참조).

---

## 1. 개요

하루코토의 수익 모델은 **프리미엄(Freemium)** 구독 기반입니다.
학습 콘텐츠(단어/문법/가나)는 무료로 제공하고, AI 회화 기능을 핵심 유료 가치로 합니다.

### 핵심 원칙

1. **학습 콘텐츠는 무료** — 단어, 문법, 가나, 퀴즈는 전 레벨(N5~N1) 무료
2. **AI가 프리미엄 핵심 가치** — AI 회화 무제한이 구독의 주요 동기
3. **무료도 충분히 쓸 만하게** — 하루 30분 AI 회화는 무료로 체험 가능
4. **한국 시장 최적화** — PortOne (포트원) V2 기반 웹 결제, 원화(KRW) 결제
5. **점진적 도입** — 유저 확보 후 결제 시스템 도입 (초기 비용 최소화)

---

## 2. 플랜 구조

### 2.1 Free (무료)

| 기능 | 제한 |
|------|------|
| JLPT 단어/문법 퀴즈 | **무제한** (N5~N1 전체) |
| 히라가나/가타카나 학습 | **무제한** |
| 게이미피케이션 (XP, 레벨, 스트릭) | **전체 이용** |
| 학습 진도 대시보드 | **전체 이용** |
| 데일리 미션 | **전체 이용** |
| 업적/뱃지 | **전체 이용** |
| AI 회화 (텍스트/음성) | **하루 30분** |
| 오답 노트 | **기본** (목록 + 재시험만) |

### 2.2 Premium (프리미엄)

| 기능 | 내용 |
|------|------|
| Free 전체 기능 | 포함 |
| AI 회화 | **무제한** (시간 제한 없음) |
| 오답 노트 + 상세 분석 | 틀린 이유 AI 분석, 약점 리포트, 관련 문법 추천 |
| 광고 제거 | 추후 광고 도입 시 프리미엄은 광고 없음 |

### 2.3 향후 확장 가능 프리미엄 기능 (미확정)

- 우선 콘텐츠 접근 (신규 N3/N2/N1 콘텐츠 조기 접근)
- AI 대화 기록 무제한 저장
- 커스텀 시나리오 생성
- 학습 리포트 PDF 내보내기

---

## 3. 가격 정책

### 3.1 가격표

| 플랜 | 가격 | 월 환산 | 할인율 |
|------|------|---------|--------|
| 월간 구독 | **₩4,900/월** | ₩4,900 | - |
| 연간 구독 | **₩39,900/년** | ₩3,325 | **32% 할인** |

> **가격 결정 근거**:
> - 듀오링고 슈퍼: ~₩8,900/월
> - 한국 학습 앱 평균: ₩5,000~₩10,000/월
> - ₩4,900은 진입 장벽을 낮춘 공격적 포지셔닝 (subscription-constants.ts 기준)

### 3.2 무료 체험 (Free Trial)

- **기간**: 7일
- **내용**: 프리미엄 전체 기능 체험
- **진입 조건**: 최초 가입 시 1회 제공
- **결제 정보**: 체험 시작 시 결제 수단 등록 필요
- **자동 전환**: 7일 후 자동으로 선택한 플랜으로 결제 시작
- **취소**: 7일 내 언제든 취소 가능 (과금 없음)

### 3.3 프로모션 전략 (안)

| 프로모션 | 내용 | 시기 |
|----------|------|------|
| 런칭 할인 | 첫 달 50% (₩3,950) | 런칭 후 1개월 |
| JLPT 시즌 | 시험 2개월 전 연간 구독 추가 할인 | 5월, 11월 |
| 친구 초대 | 초대자/피초대자 각 1개월 무료 | 상시 |

---

## 4. PG(Payment Gateway) 설계

### 4.1 PortOne V2 (포트원)

**선택 이유**:
- 한국 시장 최적화 (카드/간편결제 모두 지원)
- REST API V2 — 단순하고 일관된 인터페이스
- 빌링키 기반 정기결제(자동결제) 지원
- 합리적 수수료
- TossPayments 채널을 PortOne을 통해 연결 가능

**결제 수단**:
- 신용/체크카드 (국내 전 카드사)
- 간편결제 (토스페이, 네이버페이, 카카오페이 등)

**환경 변수 (실제 사용)**:
- `NEXT_PUBLIC_PORTONE_STORE_ID` — 스토어 ID (클라이언트 노출 가능)
- `PORTONE_CHANNEL_KEY` — 채널키 (서버)
- `PORTONE_V2_SECRET_KEY` — REST API 시크릿 (서버)
- `PORTONE_WEBHOOK_SECRET` — 웹훅 서명 검증 시크릿 (서버)

### 4.2 결제 채널

- **웹 결제만** (PWA 기반)
- 앱스토어 IAP 없음 → 30% 수수료 회피
- 추후 네이티브 앱 전환 시 IAP 추가 검토

### 4.3 PortOne V2 결제 연동 흐름

```
[클라이언트]                    [서버]                      [PortOne V2]
    │                            │                            │
    │  1. POST /subscription/     │                            │
    │     checkout {plan}         │                            │
    │ ─────────────────────────> │                            │
    │                            │  2. Payment(PENDING) 생성  │
    │                            │     paymentId 발급          │
    │ <───────────────────────── │                            │
    │  {paymentId, storeId,       │                            │
    │   channelKey, amount, ...}  │                            │
    │                            │                            │
    │  3. PortOne JS SDK로        │                            │
    │     결제창 오픈             │                            │
    │ ─────────────────────────────────────────────────────> │
    │ <───────────────────────────────────────────────────── │
    │  결제 완료 (billingKey 포함) │                            │
    │                            │                            │
    │  4. POST /subscription/     │                            │
    │     activate {paymentId,    │                            │
    │     plan}                   │                            │
    │ ─────────────────────────> │  5. getPayment(paymentId)  │
    │                            │ ─────────────────────────> │
    │                            │ <───────────────────────── │
    │                            │  결제 검증 (status=PAID,    │
    │                            │  amount 일치 확인)          │
    │                            │                            │
    │                            │  6. activateSubscription() │
    │                            │     Subscription 생성       │
    │                            │     User.isPremium 업데이트 │
    │ <───────────────────────── │                            │
    │  구독 활성화 완료            │                            │
```

### 4.4 정기결제 (빌링) 흐름

```
[Cron Job / Vercel Cron]           [서버]                  [PortOne V2]
    │                                │                          │
    │  매일 00:05 실행                │                          │
    │ ─────────────────────────────> │                          │
    │                                │  갱신 대상 구독 조회       │
    │                                │  (currentPeriodEnd ≤ now) │
    │                                │                          │
    │                                │  payWithBillingKey()     │
    │                                │ ───────────────────────> │
    │                                │ <─────────────────────── │
    │                                │   결제 성공/실패           │
    │                                │                          │
    │                                │  성공: Subscription 갱신  │
    │                                │  실패: 재시도 스케줄링     │
    │                                │                          │
```

### 4.5 웹훅 처리 흐름

```
[PortOne V2]          [POST /api/v1/webhook/portone]        [DB]
    │                            │                            │
    │  Transaction.Paid 이벤트   │                            │
    │ ─────────────────────────> │                            │
    │                            │  x-portone-signature 검증  │
    │                            │  (HMAC-SHA256)             │
    │                            │                            │
    │                            │  getPayment(paymentId)     │
    │ <───────────────────────── │                            │
    │  결제 정보 반환              │                            │
    │ ─────────────────────────> │                            │
    │                            │  기존 PENDING 결제 확인     │
    │                            │ ─────────────────────────> │
    │                            │                            │
    │                            │  activateSubscription()    │
    │                            │  (중복 처리 방지 포함)       │
    │                            │ ─────────────────────────> │
    │                            │ <───────────────────────── │
    │ <───────────────────────── │  {ok: true}                │
```

---

## 5. 데이터베이스 설계

### 5.1 현재 스키마 (User 모델)

```prisma
// 이미 존재하는 필드
isPremium            Boolean   @default(false)
subscriptionExpiresAt DateTime?
```

### 5.2 실제 구현된 모델 (schema.prisma 기준)

```prisma
// ==========================================
// 구독/결제 관련 모델
// ==========================================

model Subscription {
  id                 String             @id @default(uuid()) @db.Uuid
  userId             String             @map("user_id") @db.Uuid
  plan               SubscriptionPlan   @default(FREE) // FREE, MONTHLY, YEARLY
  status             SubscriptionStatus @default(ACTIVE) // ACTIVE, CANCELLED, EXPIRED, PAST_DUE

  // PortOne 빌링
  billingKey         String?            @map("billing_key")
  portoneCustomerId  String?            @map("portone_customer_id")

  // 기간
  currentPeriodStart DateTime           @map("current_period_start")
  currentPeriodEnd   DateTime           @map("current_period_end")
  cancelledAt        DateTime?          @map("cancelled_at")
  cancelReason       String?            @map("cancel_reason")

  createdAt          DateTime           @default(now()) @map("created_at")
  updatedAt          DateTime           @updatedAt @map("updated_at")

  user     User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  payments Payment[]

  @@index([userId])
  @@index([status])
  @@index([currentPeriodEnd])
  @@map("subscriptions")
}

model Payment {
  id               String        @id @default(uuid()) @db.Uuid
  userId           String        @map("user_id") @db.Uuid
  subscriptionId   String?       @map("subscription_id") @db.Uuid

  // PortOne
  portonePaymentId String?       @unique @map("portone_payment_id") // PortOne paymentId

  amount           Int           // 결제 금액 (원)
  currency         String        @default("KRW")
  status           PaymentStatus @default(PENDING) // PENDING, PAID, FAILED, REFUNDED, CANCELLED
  plan             SubscriptionPlan

  failReason       String?       @map("fail_reason")
  paidAt           DateTime?     @map("paid_at")
  refundedAt       DateTime?     @map("refunded_at")
  createdAt        DateTime      @default(now()) @map("created_at")
  updatedAt        DateTime      @updatedAt @map("updated_at")

  user         User          @relation(fields: [userId], references: [id], onDelete: Cascade)
  subscription Subscription? @relation(fields: [subscriptionId], references: [id], onDelete: SetNull)

  @@index([userId])
  @@index([subscriptionId])
  @@index([portonePaymentId])
  @@map("payments")
}

enum SubscriptionPlan {
  FREE
  MONTHLY
  YEARLY
}

enum SubscriptionStatus {
  ACTIVE     // 활성 구독
  PAST_DUE   // 결제 실패 (유예 기간)
  CANCELLED  // 취소됨 (기간 만료 전까지 이용 가능)
  EXPIRED    // 만료
}

enum PaymentStatus {
  PENDING    // 결제 대기 (checkout 후, activate 전)
  PAID       // 결제 성공
  FAILED     // 결제 실패
  REFUNDED   // 환불
  CANCELLED  // 취소
}
```

> **변경 사항 (TossPayments → PortOne)**:
> - `paymentKey` / `orderId` 제거 → `portonePaymentId` 단일 식별자 사용
> - `portoneCustomerId` 필드 추가 (Subscription 모델)
> - `currency` 필드 추가 (Payment 모델, 기본값 "KRW")
> - `PaymentStatus`: `SUCCESS` → `PAID`, `PENDING` 상태 추가
> - `SubscriptionPlan`: `FREE` 값 추가
> - `SubscriptionStatus`: `TRIAL` 제거 (미구현)
> - `Subscription`: `trialEndsAt`, `cancelAtPeriodEnd`, `priceAmount` 제거

### 5.3 AI 사용량 추적 모델 (실제 구현)

```prisma
model DailyAiUsage {
  id          String   @id @default(uuid()) @db.Uuid
  userId      String   @map("user_id") @db.Uuid
  date        DateTime @db.Date

  // 채팅/통화 분리 추적
  chatCount   Int      @default(0) @map("chat_count")   // 하루 채팅 세션 수
  chatSeconds Int      @default(0) @map("chat_seconds") // 하루 채팅 시간 (초)
  callCount   Int      @default(0) @map("call_count")   // 하루 통화 세션 수
  callSeconds Int      @default(0) @map("call_seconds") // 하루 통화 시간 (초)

  createdAt   DateTime @default(now()) @map("created_at")
  updatedAt   DateTime @updatedAt @map("updated_at")

  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([userId, date])
  @@index([userId, date])
  @@map("daily_ai_usage")
}
```

> **변경 사항**: `usedSeconds` 단일 필드 → 채팅/통화 분리 (chatCount, chatSeconds, callCount, callSeconds)

---

## 6. API 설계

### 6.1 구독 관련 API (실제 구현된 라우트)

```
POST   /api/v1/subscription/checkout     # paymentId 발급 + Payment(PENDING) 생성
POST   /api/v1/subscription/activate     # PortOne 결제 검증 + 구독 활성화
GET    /api/v1/subscription/status       # 현재 구독 상태 + AI 사용량 조회
POST   /api/v1/subscription/cancel       # 구독 취소 (기간 만료 시 해지)
POST   /api/v1/subscription/resume       # 취소 철회 (기간 내)

POST   /api/v1/webhook/portone           # PortOne V2 웹훅 수신 (Transaction.Paid)
```

### 6.2 결제 관련 API

```
GET    /api/v1/payments                  # 결제 내역 조회 (page 쿼리 파라미터 지원)
```

### 6.3 AI 사용량 API

```
# subscription/status 응답 내 aiUsage 필드로 통합 제공
# 별도 /api/v1/ai-usage 엔드포인트는 미구현 (chat/end, chat/start 라우트에서 내부 처리)
```

### 6.4 주요 API 응답 예시

#### `POST /api/v1/subscription/checkout` 응답

```json
{
  "paymentId": "hk_monthly_abc12345_1741130000000",
  "storeId": "store-xxxx",
  "channelKey": "channel-xxxx",
  "orderName": "하루코토 월간 프리미엄",
  "totalAmount": 4900,
  "currency": "KRW",
  "customerId": "uuid-of-user",
  "customerEmail": "user@example.com"
}
```

#### `GET /api/v1/subscription/status` 응답 (프리미엄 사용자)

```json
{
  "subscription": {
    "isPremium": true,
    "plan": "monthly",
    "expiresAt": "2026-04-05T00:00:00.000Z",
    "cancelledAt": null
  },
  "aiUsage": {
    "chatCount": 2,
    "chatSeconds": 180,
    "callCount": 0,
    "callSeconds": 0,
    "chatLimit": 999,
    "callLimit": 999,
    "chatSecondsLimit": 99999,
    "callSecondsLimit": 99999
  }
}
```

#### `GET /api/v1/subscription/status` 응답 (무료 사용자)

```json
{
  "subscription": {
    "isPremium": false,
    "plan": "free",
    "expiresAt": null,
    "cancelledAt": null
  },
  "aiUsage": {
    "chatCount": 1,
    "chatSeconds": 85,
    "callCount": 0,
    "callSeconds": 0,
    "chatLimit": 3,
    "callLimit": 1,
    "chatSecondsLimit": 300,
    "callSecondsLimit": 180
  }
}
```

---

## 7. 프론트엔드 구현 가이드

### 7.1 페이지 구조

```
/pricing                    # 가격/플랜 비교 페이지 (비로그인도 접근 가능)
/subscription/checkout      # 결제 진행 페이지 (PortOne JS SDK)
/subscription/success       # 결제 완료 페이지
/my                         # 프로필 > 구독 관리 섹션 포함
```

### 7.2 프리미엄 게이팅 패턴

```typescript
// hooks/use-subscription.ts
export function useSubscription() {
  return useQuery({
    queryKey: ['subscription', 'status'],
    queryFn: () => apiFetch('/api/v1/subscription/status'),
  });
}

export function useIsPremium() {
  const { data } = useSubscription();
  return data?.isPremium ?? false;
}

// AI 사용량 체크
export function useAiUsage() {
  const { data } = useQuery({
    queryKey: ['ai-usage', 'today'],
    queryFn: () => apiFetch('/api/v1/ai-usage/today'),
  });

  return {
    usedMinutes: data?.usedMinutes ?? 0,
    limitMinutes: data?.limitMinutes ?? 30,
    isUnlimited: data?.isUnlimited ?? false,
    remainingMinutes: data?.isUnlimited
      ? Infinity
      : Math.max(0, (data?.limitMinutes ?? 30) - (data?.usedMinutes ?? 0)),
  };
}
```

### 7.3 AI 사용 제한 UI 시나리오

**무료 사용자 제한 (subscription-constants.ts 기준)**:
- AI 채팅: 하루 3회 / 5분(300초) 이내
- AI 통화: 하루 1회 / 3분(180초) 이내

```
사용자가 AI 채팅/통화 시작 시:
  1. 서버에서 checkAiLimit(userId, 'chat'|'call') 호출
  2. 횟수 또는 시간 초과 → 업그레이드 유도 모달
  3. 제한 이내 → 시작 허용

회화 중:
  1. 무료 사용자: 남은 횟수 표시 (예: "오늘 채팅 2회 남음")
  2. 제한 도달 시 → 자연스럽게 대화 종료 + 업그레이드 유도
  3. 프리미엄 사용자: 제한 없음 (chatLimit=999, callLimit=999)

업그레이드 유도 모달:
  - "오늘 무료 AI 대화를 모두 사용했어요!"
  - "프리미엄으로 업그레이드하면 무제한으로 연습할 수 있어요"
  - [프리미엄 시작하기] / [나중에]
```

### 7.4 프로필 > 구독 관리 UI

```
구독 상태 표시:
  - 무료: "Free 플랜" + [프리미엄 시작하기] 버튼
  - 체험 중: "프리미엄 체험 중 (N일 남음)" + 플랜 선택 유도
  - 구독 중: "프리미엄 (월간/연간)" + 다음 결제일 + [구독 관리]
  - 취소 예정: "YYYY.MM.DD에 만료됩니다" + [구독 재개] 버튼

구독 관리 기능:
  - 플랜 변경 (월간 ↔ 연간)
  - 결제 수단 변경
  - 결제 내역 보기
  - 구독 취소
```

---

## 8. 보안 및 검증

### 8.1 서버 사이드 검증

```typescript
// lib/subscription-service.ts — 구독 상태 조회
export async function getSubscriptionStatus(userId: string) {
  const subscription = await prisma.subscription.findFirst({
    where: {
      userId,
      status: { in: ['ACTIVE', 'CANCELLED'] },
    },
    orderBy: { createdAt: 'desc' },
  });

  const isPremium =
    !!subscription &&
    subscription.plan !== 'FREE' &&
    subscription.status === 'ACTIVE' &&
    subscription.currentPeriodEnd > new Date();

  return { isPremium, plan: subscription?.plan, ... };
}

// lib/subscription-service.ts — AI 사용 제한 체크 (채팅/통화 분리)
export async function checkAiLimit(
  userId: string,
  type: 'chat' | 'call'
): Promise<{ allowed: boolean; reason?: string }> {
  const { isPremium } = await getSubscriptionStatus(userId);
  const limits = isPremium ? AI_LIMITS.PREMIUM : AI_LIMITS.FREE;
  const usage = await getDailyAiUsage(userId);

  if (type === 'chat') {
    if (usage.chatCount >= limits.CHAT_COUNT) return { allowed: false, reason: '횟수 초과' };
    if (usage.chatSeconds >= limits.CHAT_SECONDS) return { allowed: false, reason: '시간 초과' };
  } else {
    if (usage.callCount >= limits.CALL_COUNT) return { allowed: false, reason: '횟수 초과' };
    if (usage.callSeconds >= limits.CALL_SECONDS) return { allowed: false, reason: '시간 초과' };
  }

  return { allowed: true };
}
```

### 8.2 웹훅 보안

```typescript
// PortOne V2 웹훅 시그니처 검증
// POST /api/v1/webhook/portone
export async function POST(request: Request) {
  const bodyText = await request.text();
  const signature = request.headers.get('x-portone-signature'); // PortOne V2 헤더명

  // HMAC SHA-256으로 서명 검증 (lib/portone.ts verifyWebhookSignature 사용)
  const webhookSecret = process.env.PORTONE_WEBHOOK_SECRET;
  if (webhookSecret && !verifyWebhookSignature(bodyText, signature, webhookSecret)) {
    return NextResponse.json({ error: 'Invalid signature' }, { status: 401 });
  }

  const body = JSON.parse(bodyText);
  const { type, data } = body;

  // 지원 이벤트: Transaction.Paid
  // 중복 처리 방지: portonePaymentId로 기존 PAID 레코드 확인 후 스킵
}
```

### 8.3 결제 실패 처리

```
결제 실패 시 재시도 정책:
  1일차: 1회 재시도
  3일차: 2회차 재시도
  5일차: 3회차 재시도 (최종)
  7일차: 구독 만료 처리

각 재시도 시:
  - 이메일/푸시 알림 발송
  - 인앱 배너로 결제 수단 업데이트 유도

유예 기간 (Grace Period):
  - 결제 실패 후 7일간은 프리미엄 유지
  - status: PAST_DUE
  - 7일 경과 시 status: EXPIRED, isPremium: false
```

---

## 9. 구현 우선순위 (로드맵)

### Phase 0: 무료 런칭 — 지금 구현 ✅

> 결제 없이 AI 사용량 제한만 적용하여 런칭한다.

1. DB 마이그레이션 (DailyAiUsage 모델만)
2. AI 사용량 추적 API (`/api/v1/ai-usage/*`)
3. AI 회화 시작 시 서버 사이드 사용량 체크 + 30분 제한
4. 무료 사용자: 회화 중 남은 시간 표시 UI
5. 30분 소진 시: "오늘 무료 회화 시간을 모두 사용했어요!" 안내

### Phase 1: 결제 기반 — 전환 트리거 충족 시 ✅ (완료)

> PortOne V2 가맹점 신청 + 결제 연동

1. PortOne V2 가맹점 심사 + 채널 설정
2. DB 마이그레이션 (Subscription, Payment 모델 추가) ✅
3. PortOne V2 REST API 연동 (`lib/portone.ts`) ✅
4. `/pricing` 가격 페이지 ✅
5. `/subscription/checkout` 결제 플로우 ✅
6. 빌링키 발급 + 첫 결제 (PortOne JS SDK) ✅
7. 구독 활성화 + `isPremium` 업데이트 ✅

### Phase 2: 구독 관리 ✅ (완료)

1. 프로필 내 구독 관리 섹션 ✅
2. 구독 취소/재개 (`/subscription/cancel`, `/subscription/resume`) ✅
3. 결제 내역 조회 (`/payments`) ✅
4. 결제 수단 변경 (미구현)
5. 7일 무료 체험 플로우 (미구현)

### Phase 3: 운영 안정화

1. 정기결제 Cron Job (Vercel Cron)
2. PortOne 웹훅 수신 + 처리 (`/webhook/portone`) ✅
3. 결제 실패 재시도 로직
4. 이메일/푸시 알림 연동
5. 환불 처리 (`cancelPayment()` in `lib/portone.ts` 구현됨, API 라우트 미연결)

---

## 10. 환경 변수

```env
# PortOne V2
NEXT_PUBLIC_PORTONE_STORE_ID=store-xxx  # 스토어 ID (클라이언트 노출 가능)
PORTONE_CHANNEL_KEY=channel-xxx         # 채널키 (서버 전용)
PORTONE_V2_SECRET_KEY=xxx               # REST API 시크릿 (서버 전용)
PORTONE_WEBHOOK_SECRET=xxx              # 웹훅 서명 검증 시크릿 (서버 전용)

# 구독 설정 (subscription-constants.ts에 하드코딩되어 있으나, 환경 변수로 분리 가능)
# PRICES.MONTHLY = 4900
# PRICES.YEARLY  = 39900
```

> **TossPayments 변수 삭제**: `TOSS_CLIENT_KEY`, `TOSS_SECRET_KEY`, `TOSS_WEBHOOK_SECRET`은 더 이상 사용하지 않는다.

---

## 11. 참고 사항

### PortOne V2 가맹점 등록

- 결제 연동 전 **사업자 등록 + PortOne 가맹점 심사** 필요
- PortOne 콘솔: https://admin.portone.io
- 채널 설정: PortOne 콘솔 > 결제 연동 > 채널 관리에서 TossPayments 채널 추가
- 테스트 모드는 심사 없이 바로 사용 가능
- REST API V2 문서: https://developers.portone.io/api/rest-v2

### 부가가치세 (VAT)

- 디지털 콘텐츠 공급 → 부가가치세 10% 포함 가격 설정
- ₩4,900 (VAT 포함) → 공급가 ₩4,455 / VAT ₩445

### 전자상거래 관련 법률

- 구독 서비스 → **청약철회 기간** (7일) 고려
- 자동 결제 전환 시 **사전 고지** 필수 (결제 3일 전 알림)
- 구독 취소 버튼은 **가입과 동일한 수준으로 쉽게** 접근 가능해야 함
- 개인정보 처리방침에 결제 정보 수집/이용 항목 추가 필요

### 추후 고려사항

- 네이티브 앱 출시 시 Apple/Google IAP 대응 필요
- 환율 변동 시 가격 조정 정책
- 기업/학교 단체 구독 (B2B) 모델
- 쿠폰/프로모션 코드 시스템
