# 결제/구독 시스템 설계 문서

> **상태**: 설계 완료 / 구현 전
> **최종 업데이트**: 2026-03-04
> **대상 시장**: 한국 (KR)

---

## 0. 단계별 출시 전략

> **핵심**: 결제 시스템은 유저 확보 후 도입한다.

### 현재 단계 — 무료 런칭 (결제 없음)

토스페이먼츠 가맹점 등록비 22만원 + 연회비 11만원의 초기 비용이 발생하므로,
유저가 없는 상태에서 선투자하지 않는다.

**지금 구현할 것:**
- AI 회화 **하루 30분 제한**만 서버에서 적용 (DailyAiUsage 모델 + 체크 로직)
- 무료 사용자에게 남은 시간 표시 UI
- 프리미엄/결제 관련 UI는 **노출하지 않음**

**지금 구현하지 않을 것:**
- 토스페이먼츠 SDK 연동
- 구독/결제 API
- Pricing 페이지
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
4. **한국 시장 최적화** — 토스페이먼츠 기반 웹 결제, 원화(KRW) 결제
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
| 월간 구독 | **₩7,900/월** | ₩7,900 | - |
| 연간 구독 | **₩71,000/년** | ₩5,917 | **25% 할인** (3개월 무료) |

> **가격 결정 근거**:
> - 듀오링고 슈퍼: ~₩8,900/월
> - 한국 학습 앱 평균: ₩5,000~₩10,000/월
> - ₩7,900은 중간 포지셔닝으로, 커피 한 잔 가격 마케팅 가능

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

### 4.1 토스페이먼츠 (Toss Payments)

**선택 이유**:
- 한국 시장 최적화 (카드/계좌이체/간편결제 모두 지원)
- 개발자 친화적 REST API + 우수한 문서
- Next.js/React SDK 공식 지원
- 정기결제(빌링) 기능 내장
- 합리적 수수료 (PG 수수료 ~3.3% + VAT)

**결제 수단**:
- 신용/체크카드 (국내 전 카드사)
- 계좌이체
- 간편결제 (토스페이, 네이버페이, 카카오페이 등)

### 4.2 결제 채널

- **웹 결제만** (PWA 기반)
- 앱스토어 IAP 없음 → 30% 수수료 회피
- 추후 네이티브 앱 전환 시 IAP 추가 검토

### 4.3 토스페이먼츠 연동 흐름

```
[클라이언트]                    [서버]                     [토스페이먼츠]
    │                            │                            │
    │  1. 구독 시작 요청          │                            │
    │ ─────────────────────────> │                            │
    │                            │  2. 빌링키 발급 요청        │
    │                            │ ─────────────────────────> │
    │                            │                            │
    │  3. 카드 정보 입력 위젯     │ <───────────────────────── │
    │ <───────────────────────── │     결제 위젯 URL           │
    │                            │                            │
    │  4. 카드 정보 입력 완료     │                            │
    │ ─────────────────────────> │  5. 빌링키 확인             │
    │                            │ ─────────────────────────> │
    │                            │ <───────────────────────── │
    │                            │     billingKey              │
    │                            │                            │
    │                            │  6. 첫 결제 실행            │
    │                            │ ─────────────────────────> │
    │                            │ <───────────────────────── │
    │  7. 구독 활성화             │     결제 성공               │
    │ <───────────────────────── │                            │
```

### 4.4 정기결제 (빌링) 흐름

```
[Cron Job / Vercel Cron]           [서버]                [토스페이먼츠]
    │                                │                        │
    │  매일 00:05 실행                │                        │
    │ ─────────────────────────────> │                        │
    │                                │  결제 예정 구독 조회     │
    │                                │  (expiresAt ≤ today)    │
    │                                │                        │
    │                                │  billingKey로 결제 요청  │
    │                                │ ─────────────────────> │
    │                                │ <───────────────────── │
    │                                │   결제 성공/실패         │
    │                                │                        │
    │                                │  성공: 구독 갱신         │
    │                                │  실패: 재시도 스케줄링   │
    │                                │                        │
```

---

## 5. 데이터베이스 설계

### 5.1 현재 스키마 (User 모델)

```prisma
// 이미 존재하는 필드
isPremium            Boolean   @default(false)
subscriptionExpiresAt DateTime?
```

### 5.2 추가 필요 모델

```prisma
// ==========================================
// 구독/결제 관련 모델
// ==========================================

model Subscription {
  id                String             @id @default(uuid()) @db.Uuid
  userId            String             @map("user_id") @db.Uuid
  plan              SubscriptionPlan   // MONTHLY, YEARLY
  status            SubscriptionStatus // ACTIVE, CANCELLED, PAST_DUE, EXPIRED, TRIAL

  // 토스페이먼츠 빌링
  billingKey        String?            @map("billing_key")

  // 기간
  currentPeriodStart DateTime          @map("current_period_start")
  currentPeriodEnd   DateTime          @map("current_period_end")
  trialEndsAt        DateTime?         @map("trial_ends_at")
  cancelledAt        DateTime?         @map("cancelled_at")
  cancelAtPeriodEnd  Boolean           @default(false) @map("cancel_at_period_end")

  // 가격 (결제 당시 가격 기록)
  priceAmount        Int               @map("price_amount") // 원 단위

  createdAt          DateTime          @default(now()) @map("created_at")
  updatedAt          DateTime          @updatedAt @map("updated_at")

  user              User               @relation(fields: [userId], references: [id], onDelete: Cascade)
  payments          Payment[]

  @@map("subscriptions")
}

model Payment {
  id              String        @id @default(uuid()) @db.Uuid
  subscriptionId  String        @map("subscription_id") @db.Uuid
  userId          String        @map("user_id") @db.Uuid

  // 토스페이먼츠
  paymentKey      String?       @unique @map("payment_key") // 토스 paymentKey
  orderId         String        @unique @map("order_id")    // 우리 주문 ID

  amount          Int           // 결제 금액 (원)
  status          PaymentStatus // SUCCESS, FAILED, REFUNDED, CANCELLED

  // 결제 수단 정보
  method          String?       // CARD, TRANSFER, etc.
  cardCompany     String?       @map("card_company")
  cardNumber      String?       @map("card_number") // 마스킹된 번호 (끝 4자리)
  receiptUrl      String?       @map("receipt_url")

  failReason      String?       @map("fail_reason")

  paidAt          DateTime?     @map("paid_at")
  createdAt       DateTime      @default(now()) @map("created_at")

  subscription    Subscription  @relation(fields: [subscriptionId], references: [id])
  user            User          @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@map("payments")
}

enum SubscriptionPlan {
  MONTHLY
  YEARLY
}

enum SubscriptionStatus {
  TRIAL      // 무료 체험 중
  ACTIVE     // 활성 구독
  PAST_DUE   // 결제 실패 (유예 기간)
  CANCELLED  // 취소됨 (기간 만료 전까지 이용 가능)
  EXPIRED    // 만료
}

enum PaymentStatus {
  SUCCESS
  FAILED
  REFUNDED
  CANCELLED
}
```

### 5.3 AI 사용량 추적 모델

```prisma
model DailyAiUsage {
  id        String   @id @default(uuid()) @db.Uuid
  userId    String   @map("user_id") @db.Uuid
  date      DateTime @db.Date

  // 시간 기반 사용량 (초 단위)
  usedSeconds Int    @default(0) @map("used_seconds")

  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([userId, date])
  @@map("daily_ai_usage")
}
```

---

## 6. API 설계

### 6.1 구독 관련 API

```
POST   /api/v1/subscription/checkout     # 구독 시작 (빌링키 발급)
POST   /api/v1/subscription/activate     # 결제 확인 + 구독 활성화
GET    /api/v1/subscription/status       # 현재 구독 상태 조회
POST   /api/v1/subscription/cancel       # 구독 취소 (기간 만료 시 해지)
POST   /api/v1/subscription/resume       # 취소 철회 (기간 내)

POST   /api/v1/webhook/toss             # 토스페이먼츠 웹훅 수신
```

### 6.2 결제 관련 API

```
GET    /api/v1/payments                  # 결제 내역 조회
GET    /api/v1/payments/:id              # 결제 상세
POST   /api/v1/payments/refund           # 환불 요청
```

### 6.3 AI 사용량 API

```
GET    /api/v1/ai-usage/today            # 오늘 AI 사용량 조회
POST   /api/v1/ai-usage/track            # AI 사용 시간 기록 (내부용)
```

### 6.4 주요 API 응답 예시

#### `GET /api/v1/subscription/status`

```json
{
  "hasSubscription": true,
  "isPremium": true,
  "plan": "MONTHLY",
  "status": "ACTIVE",
  "currentPeriodEnd": "2026-04-04T00:00:00Z",
  "cancelAtPeriodEnd": false,
  "trial": {
    "isTrialing": false,
    "trialEndsAt": null
  },
  "aiUsage": {
    "usedMinutes": 12,
    "limitMinutes": null,
    "isUnlimited": true
  }
}
```

#### 무료 사용자 응답

```json
{
  "hasSubscription": false,
  "isPremium": false,
  "plan": null,
  "status": null,
  "trial": {
    "isTrialing": false,
    "trialEndsAt": null,
    "trialAvailable": true
  },
  "aiUsage": {
    "usedMinutes": 18,
    "limitMinutes": 30,
    "isUnlimited": false
  }
}
```

---

## 7. 프론트엔드 구현 가이드

### 7.1 페이지 구조

```
/pricing                    # 가격/플랜 비교 페이지 (비로그인도 접근 가능)
/subscription/checkout      # 결제 진행 페이지 (토스 위젯)
/subscription/success       # 결제 완료 페이지
/profile                    # 프로필 > 구독 관리 섹션 포함
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

```
사용자가 AI 회화 시작 시:
  1. useAiUsage()로 남은 시간 확인
  2. 남은 시간 > 0 → 회화 시작, 타이머 표시
  3. 남은 시간 = 0 → 업그레이드 유도 모달
  4. 프리미엄 사용자 → 제한 없이 시작

회화 중:
  1. 무료 사용자: 상단에 남은 시간 표시 (예: "남은 시간: 12:30")
  2. 30분 도달 시 → 자연스럽게 대화 종료 + 업그레이드 유도
  3. 프리미엄 사용자: 타이머 없음

업그레이드 유도 모달:
  - "오늘 무료 회화 시간을 모두 사용했어요!"
  - "프리미엄으로 업그레이드하면 무제한으로 연습할 수 있어요"
  - [7일 무료 체험 시작하기] / [나중에]
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
// 모든 프리미엄 기능 접근 시 서버에서 검증
async function requirePremium(userId: string): Promise<boolean> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { isPremium: true, subscriptionExpiresAt: true },
  });

  if (!user) return false;

  // isPremium이 true이고 만료되지 않았는지 확인
  if (user.isPremium && user.subscriptionExpiresAt) {
    return user.subscriptionExpiresAt > new Date();
  }

  return false;
}

// AI 사용량 서버 사이드 체크
async function checkAiLimit(userId: string): Promise<{
  allowed: boolean;
  remainingSeconds: number;
}> {
  const isPremium = await requirePremium(userId);
  if (isPremium) return { allowed: true, remainingSeconds: Infinity };

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const usage = await prisma.dailyAiUsage.findUnique({
    where: { userId_date: { userId, date: today } },
  });

  const usedSeconds = usage?.usedSeconds ?? 0;
  const limitSeconds = 30 * 60; // 30분
  const remaining = Math.max(0, limitSeconds - usedSeconds);

  return { allowed: remaining > 0, remainingSeconds: remaining };
}
```

### 8.2 웹훅 보안

```typescript
// 토스페이먼츠 웹훅 시그니처 검증
// POST /api/v1/webhook/toss
export async function POST(request: Request) {
  const body = await request.text();
  const signature = request.headers.get('Toss-Signature');

  // HMAC SHA-256으로 서명 검증
  const isValid = verifyTossSignature(body, signature, TOSS_WEBHOOK_SECRET);
  if (!isValid) {
    return NextResponse.json({ error: 'Invalid signature' }, { status: 401 });
  }

  // 웹훅 처리...
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

### Phase 1: 결제 기반 — 전환 트리거 충족 시

> 토스페이먼츠 가맹점 신청 + 결제 연동

1. 토스페이먼츠 사업자 등록 + 가맹점 심사 (3~5 영업일)
2. DB 마이그레이션 (Subscription, Payment 모델 추가)
3. 토스페이먼츠 SDK 연동
4. `/pricing` 가격 페이지
5. `/subscription/checkout` 결제 플로우
6. 빌링키 발급 + 첫 결제
7. 구독 활성화 + `isPremium` 업데이트

### Phase 2: 구독 관리

1. 프로필 내 구독 관리 섹션
2. 구독 취소/재개
3. 결제 내역 조회
4. 결제 수단 변경
5. 7일 무료 체험 플로우

### Phase 3: 운영 안정화

1. 정기결제 Cron Job (Vercel Cron)
2. 토스 웹훅 수신 + 처리
3. 결제 실패 재시도 로직
4. 이메일/푸시 알림 연동
5. 환불 처리

---

## 10. 환경 변수

```env
# 토스페이먼츠
TOSS_CLIENT_KEY=test_ck_xxx              # 클라이언트 키 (프론트)
TOSS_SECRET_KEY=test_sk_xxx              # 시크릿 키 (서버)
TOSS_WEBHOOK_SECRET=whsec_xxx            # 웹훅 시크릿

# 구독 설정
SUBSCRIPTION_MONTHLY_PRICE=7900          # 월간 구독 가격 (원)
SUBSCRIPTION_YEARLY_PRICE=71000          # 연간 구독 가격 (원)
FREE_AI_DAILY_LIMIT_MINUTES=30           # 무료 AI 일일 제한 (분)
FREE_TRIAL_DAYS=7                        # 무료 체험 기간 (일)
```

---

## 11. 참고 사항

### 토스페이먼츠 사업자 등록

- 결제 연동 전 **사업자 등록 + 토스페이먼츠 가맹점 심사** 필요
- **초기 비용**: 등록비 ₩220,000 + 연회비 ₩110,000 = **₩330,000**
- 심사 기간: 보통 3~5 영업일
- 필요 서류: 사업자등록증, 통장 사본, 서비스 URL
- 테스트 모드는 심사 없이 바로 사용 가능
- **전략**: 유저 확보 전에는 가입하지 않고, 전환 트리거 충족 시 신청 (0장 참조)

### 부가가치세 (VAT)

- 디지털 콘텐츠 공급 → 부가가치세 10% 포함 가격 설정
- ₩7,900 (VAT 포함) → 공급가 ₩7,182 / VAT ₩718

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
