# 하루코토 인프라 현황 & GCP 도입 분석

> 최종 업데이트: 2026-03-04

---

## 1. 현재 인프라 스택

### 호스팅 & 배포

| 항목 | 현재 | 비고 |
|------|------|------|
| **웹앱 호스팅** | Vercel (Pro) | Next.js 16.1, 자동 배포 |
| **랜딩 페이지** | Vercel | SSG static export |
| **모바일** | Flutter WebView | iOS/Android, `app.harukoto.co.kr` 연결 |
| **도메인** | `harukoto.co.kr` / `app.harukoto.co.kr` | |
| **CI/CD** | Vercel 자동 배포 | GitHub Actions 없음 |
| **Cron** | Vercel Cron | 일일 리마인더 (매일 00:00 UTC) |

### 데이터베이스 & 스토리지

| 항목 | 현재 | 비고 |
|------|------|------|
| **DB** | Supabase PostgreSQL 15+ | Prisma ORM, PgBouncer 풀링 |
| **캐시** | 없음 (인메모리 rate limiter만) | Redis 미사용 |
| **파일 스토리지** | 없음 | Supabase Storage 가용하나 미사용 |
| **CDN** | Vercel 기본 Edge Network | 별도 CDN 없음 |

### 인증 & 보안

| 항목 | 현재 | 비고 |
|------|------|------|
| **인증** | Supabase Auth | Google, Kakao OAuth |
| **세션** | httpOnly Cookie | SSR 세션 관리 |
| **Rate Limiting** | 인메모리 슬라이딩 윈도우 | AI: 20/min, API: 60/min, Auth: 10/min |
| **입력 검증** | Zod | 모든 API Route에 적용 |

### AI / LLM

| 항목 | 현재 | 비고 |
|------|------|------|
| **주 AI** | Google Gemini (`gemini-2.5-flash`) | 텍스트 + 음성 회화 |
| **보조 AI** | OpenAI (`gpt-4o-mini`) | Fallback |
| **SDK** | Vercel AI SDK + `@google/genai` | Live API (v1alpha) |
| **TTS/STT** | Google Gemini Live API | 실시간 음성 처리 |

### 모니터링 & 알림

| 항목 | 현재 | 비고 |
|------|------|------|
| **에러 추적** | Sentry | 서버/클라이언트/Edge, Session Replay |
| **로깅** | console + Sentry | 구조화된 로깅 시스템 없음 |
| **분석** | 없음 | 사용자 행동 분석 미구축 |
| **푸시 알림** | Web Push (VAPID) | `web-push` 패키지 |
| **이메일** | 없음 | 트랜잭션 이메일 미구축 |

### 결제

| 항목 | 현재 | 비고 |
|------|------|------|
| **결제** | 미구현 | PRD에 프리미엄 플랜 기획 존재, Stripe 미연동 |

---

## 2. 아키텍처 다이어그램 (현재)

```
[Flutter App] ──WebView──▶ [Vercel Edge Network]
[Browser]    ─────────────▶     │
                                ▼
                         [Next.js 16 App]
                           │        │
                    API Routes   SSR/RSC
                      │    │        │
            ┌─────────┘    │        │
            ▼              ▼        ▼
     [Supabase Auth]  [Prisma]  [AI SDK]
            │              │        │
            ▼              ▼        ▼
     [Supabase]      [PostgreSQL] [Gemini/OpenAI]
     (OAuth)         (via PgBouncer)

     [Sentry] ◀── Error Tracking
     [Web Push] ◀── VAPID Notifications
```

---

## 3. 현재 아키텍처의 한계점

| 한계 | 영향 | 심각도 |
|------|------|--------|
| **인메모리 Rate Limiter** | Vercel Serverless는 인스턴스마다 메모리 분리. 실질적으로 rate limiting이 작동 안 함 | 높음 |
| **캐시 레이어 없음** | 매 요청마다 DB 직접 조회. 프로필, 단어장 등 반복 조회 비효율 | 중간 |
| **구조화된 로깅 없음** | 디버깅 시 Vercel 로그만 의존. 검색/집계 불가 | 중간 |
| **사용자 분석 없음** | 퍼널, 리텐션, 이탈 지점 파악 불가 | 중간 |
| **이메일 없음** | 비활성 유저 리인게이지먼트 수단 없음 | 낮음 |
| **백그라운드 작업 제한** | Vercel Cron만 사용. 복잡한 비동기 작업 처리 불가 | 낮음 |

---

## 4. GCP 서비스 도입 분석 ($950 크레딧)

### 4-1. 강력 추천 — 즉시 ROI

#### Redis (Cloud Memorystore) → Rate Limiting + 캐시

| 항목 | 내용 |
|------|------|
| **해결하는 문제** | 인메모리 rate limiter가 Serverless에서 무의미, DB 반복 조회 |
| **적용 대상** | Rate limiting, 프로필 캐시, 단어장 캐시, 세션 캐시 |
| **GCP 서비스** | Cloud Memorystore for Redis (Basic tier) |
| **예상 비용** | Basic M1 (1GB): ~$35/월 |
| **$950으로** | ~27개월 운영 가능 |
| **도입 난이도** | 낮음 — `ioredis` + 기존 rate-limit.ts 교체 |

**Tradeoff:**
- (+) Serverless 환경에서 진짜 작동하는 rate limiting
- (+) DB 부하 감소 (프로필, 대시보드 등 캐싱)
- (+) 세션 공유 가능
- (-) Vercel ↔ GCP 간 네트워크 레이턴시 (같은 region이면 ~5ms)
- (-) 관리 포인트 1개 추가 (Supabase + GCP)

#### Cloud Logging + Error Reporting → 구조화 로깅

| 항목 | 내용 |
|------|------|
| **해결하는 문제** | console.log 기반 디버깅, 로그 검색 불가 |
| **GCP 서비스** | Cloud Logging (Operations Suite) |
| **예상 비용** | 50GB/월 무료, 이후 $0.50/GB |
| **$950으로** | 사실상 무료 (무료 티어 내 충분) |
| **도입 난이도** | 낮음 — winston/pino + GCP transport |

**Tradeoff:**
- (+) 구조화된 로그 검색, 필터링, 알림 설정
- (+) Sentry와 상호보완 (Sentry=에러, Cloud Logging=전체 흐름)
- (+) 무료 티어가 넉넉
- (-) Sentry와 역할 일부 중복
- (-) 로깅 코드 추가 필요 (console → logger 교체)

---

### 4-2. 추천 — 성장 단계에서 가치

#### BigQuery + GA4 → 사용자 분석

| 항목 | 내용 |
|------|------|
| **해결하는 문제** | 사용자 행동 분석 전무 |
| **GCP 서비스** | Google Analytics 4 (무료) + BigQuery (export) |
| **예상 비용** | GA4 무료, BigQuery 10GB/월 무료 + 1TB 쿼리/월 무료 |
| **$950으로** | 사실상 무료 (무료 티어 내) |
| **도입 난이도** | 낮음 — gtag 스크립트 + 이벤트 전송 |

**Tradeoff:**
- (+) 퍼널 분석, 리텐션, 학습 패턴 파악
- (+) BigQuery export로 커스텀 분석 가능
- (+) 무료
- (-) GA4 학습 곡선
- (-) 개인정보 처리방침 업데이트 필요

#### Cloud Tasks / Cloud Scheduler → 백그라운드 작업

| 항목 | 내용 |
|------|------|
| **해결하는 문제** | Vercel Cron 제한 (1일 1회, 간단한 작업만) |
| **적용 대상** | 스페이스드 리피티션 알림, 주간 리포트, 업적 집계 |
| **GCP 서비스** | Cloud Tasks + Cloud Scheduler |
| **예상 비용** | Cloud Tasks 100만/월 무료, Scheduler 3잡/월 무료 |
| **$950으로** | 사실상 무료 |
| **도입 난이도** | 중간 — 워커 엔드포인트 구현 필요 |

**Tradeoff:**
- (+) 복잡한 비동기 작업 처리 (알림 배치, 통계 집계 등)
- (+) 재시도, 딜레이, 큐잉 기본 지원
- (-) Vercel Functions에서 GCP로 아키텍처 분산
- (-) 현 단계에서는 Vercel Cron으로 충분할 수 있음

---

### 4-3. 고려 가능 — 특정 상황에서 가치

#### Cloud Run → AI 전용 백엔드

| 항목 | 내용 |
|------|------|
| **해결하는 문제** | Vercel Serverless 10초/60초 타임아웃, AI 응답 긴 경우 |
| **GCP 서비스** | Cloud Run (컨테이너 서버리스) |
| **예상 비용** | 무료 티어: 200만 요청/월, 360,000 vCPU-초/월 |
| **$950으로** | 무료 티어 + 초과분 ~12개월+ |
| **도입 난이도** | 높음 — Dockerfile 작성, 배포 파이프라인 구축 |

**Tradeoff:**
- (+) 타임아웃 자유 설정 (최대 60분)
- (+) Gemini API와 같은 GCP 네트워크 → 레이턴시 최소
- (+) WebSocket/SSE 장시간 연결 가능
- (-) 배포 파이프라인 별도 구축 필요
- (-) 현재 Vercel로 충분히 동작 중
- (-) 아키텍처 복잡도 증가

#### Cloud Storage → 정적 파일 / 사용자 업로드

| 항목 | 내용 |
|------|------|
| **해결하는 문제** | 파일 스토리지 미구축 (아바타 업로드 등) |
| **GCP 서비스** | Cloud Storage (Standard) |
| **예상 비용** | 5GB 무료, 이후 $0.02/GB/월 |
| **$950으로** | 사실상 무료 |
| **도입 난이도** | 중간 |

**Tradeoff:**
- (+) Supabase Storage 대비 GCP CDN 통합이 더 강력
- (-) Supabase Storage로 충분한 규모
- (-) 관리 포인트 분산

#### Vertex AI → Gemini API 대체

| 항목 | 내용 |
|------|------|
| **해결하는 문제** | Gemini API 직접 호출 비용 |
| **GCP 서비스** | Vertex AI (Gemini 모델 호스팅) |
| **예상 비용** | $950 크레딧 적용 가능 |
| **도입 난이도** | 낮음 — SDK 엔드포인트 변경만 |

**Tradeoff:**
- (+) $950 크레딧으로 AI API 비용 직접 충당 가능
- (+) 같은 Gemini 모델, 동일 API
- (+) GCP 내부 네트워크 활용 시 레이턴시 감소
- (-) API 키 방식 → 서비스 계정 인증으로 변경 필요
- (-) Vercel AI SDK `@ai-sdk/google` 호환성 확인 필요

---

### 4-4. 비추천 — 현 단계 불필요

| 서비스 | 이유 |
|--------|------|
| **Cloud SQL** | 이미 Supabase PostgreSQL 사용 중. 이중 DB는 낭비 |
| **GKE (Kubernetes)** | 오버엔지니어링. 학습앱에 K8s 불필요 |
| **Firebase** | Supabase와 역할 중복 (Auth, DB, Storage 전부) |
| **Cloud CDN** | Vercel Edge Network가 이미 CDN 역할 수행 |
| **Pub/Sub** | 현 규모에서 메시지 큐 불필요. Cloud Tasks면 충분 |

---

## 5. 추천 도입 우선순위

| 순위 | 서비스 | 예상 비용 | 이유 |
|------|--------|-----------|------|
| **1** | **Vertex AI (Gemini)** | ~$950 크레딧 직접 사용 | 현재 가장 큰 운영비인 AI API 비용을 크레딧으로 충당 |
| **2** | **Cloud Memorystore (Redis)** | ~$35/월 | Rate limiting 실질 작동 + 캐시로 DB 부하 감소 |
| **3** | **GA4 + BigQuery** | 무료 | 사용자 분석 기반 마련. 도입 비용 최소 |
| **4** | **Cloud Logging** | 무료 | 운영 가시성 확보. Sentry 보완 |
| **5** | **Cloud Tasks** | 무료 | 성장 시 백그라운드 작업 확장 |

---

## 6. $950 크레딧 최적 배분안

```
총 크레딧: $950

[1] Vertex AI (Gemini API)    — ~$600  (AI 호출 비용 6~12개월분)
[2] Cloud Memorystore (Redis) — ~$250  (7개월 운영)
[3] Cloud Logging / BigQuery  — ~$50   (무료 티어 초과분 버퍼)
[4] 기타 실험/테스트          — ~$50   (Cloud Run 프로토타이핑 등)
                               ------
                               $950
```

---

## 7. 도입 시 주의사항

1. **Region 통일** — Vercel(ICN), Supabase, GCP 모두 `asia-northeast3` (서울) 사용 권장. 크로스 리전 레이턴시 방지
2. **크레딧 만료일 확인** — GCP 크레딧에 보통 12개월 유효기간 있음. 만료 전 소진 계획 필요
3. **점진적 도입** — 한꺼번에 전환하지 말고, Vertex AI → Redis → 나머지 순으로 단계적 적용
4. **Vercel 의존도 유지** — 배포/CDN/SSR은 Vercel이 최적. GCP는 보조 인프라로 활용
5. **비용 알림 설정** — GCP Budget Alert으로 월별 소진량 모니터링 필수
