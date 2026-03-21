# 하루코토 화면 설계서 (Screen Design Specifications)

> 현재 구현된 모든 화면의 레이아웃, 섹션 구성, 컴포넌트 매핑, 인터랙션을 문서화.
> AI(Claude/Gemini)가 화면 고도화 작업 시 참고할 수 있도록 ASCII 와이어프레임 포함.

---

## 문서 목록

| 문서 | 화면 | 라우트 |
|------|------|--------|
| [01-HOME.md](./01-HOME.md) | 홈 (대시보드) | `/home` |
| [02-STUDY.md](./02-STUDY.md) | 학습 (퀴즈, 가나, 단어장) | `/study/**` |
| [03-CHAT.md](./03-CHAT.md) | AI 회화 (텍스트 채팅, 음성통화) | `/chat/**` |
| [04-STATS.md](./04-STATS.md) | 통계 | `/stats` |
| [05-MY.md](./05-MY.md) | 마이페이지 (프로필, 설정) | `/my/**` |
| [06-AUTH.md](./06-AUTH.md) | 인증 & 온보딩 | `/login`, `/onboarding` |
| [07-SUBSCRIPTION.md](./07-SUBSCRIPTION.md) | 구독 & 결제 | `/pricing`, `/subscription/**` |
| [08-QUIZ-UI.md](./08-QUIZ-UI.md) | 퀴즈 컴포넌트 상세 (4지선다, 2×2, 매칭) | 공통 컴포넌트 |
| [09-QUIZ-V2.md](./09-QUIZ-V2.md) | 학습 고도화 UI (빈칸, 어순, 입력, 개편) | Phase 2~6 |

---

## 전체 화면 맵 (Sitemap)

```
하루코토 (HaruKoto)
│
├── 🔐 인증 그룹 (auth)
│   ├── /login ─────────────── 로그인 (소셜 + 이메일)
│   └── /onboarding ────────── 온보딩 (닉네임 → 레벨 → 목표)
│
├── 📱 메인 앱 (app) ─── BottomNav 포함
│   │
│   ├── 🏠 /home ──────────── 대시보드
│   │   ├── PhoneCallCta (AI 통화 배너)
│   │   ├── KanaCtaCard (가나 학습 유도, 조건부)
│   │   ├── StreakBadge + DailyProgressCard
│   │   ├── DailyMissionsCard (오늘의 미션)
│   │   ├── QuickStartCard (학습 시작)
│   │   ├── WeeklyChart (주간 차트)
│   │   └── LevelProgress (JLPT 진도)
│   │
│   ├── 📊 /stats ─────────── 학습 통계
│   │   ├── [기간별] Heatmap + BarChart
│   │   ├── [학습별] 카테고리별 통계 카드
│   │   └── [JLPT진도] 레벨별 진행률
│   │
│   ├── 📚 /study ─────────── 학습
│   │   ├── /study ──────────── 학습 메인 (레벨/유형 선택)
│   │   ├── /study/quiz ─────── JLPT 퀴즈 (4지선다)
│   │   ├── /study/result ───── 퀴즈 결과
│   │   ├── /study/wrong-answers ── 오답노트
│   │   ├── /study/learned-words ── 학습한 단어 목록
│   │   ├── /study/wordbook ──── 내 단어장
│   │   └── /study/kana ─────── 가나 학습
│   │       ├── /study/kana ──────── 가나 메인 (히라가나/가타카나)
│   │       ├── /study/kana/[type] ── 스테이지 목록
│   │       ├── /study/kana/[type]/stage/[n] ── 스테이지 학습
│   │       │   └── Intro → Flashcard → Matching → Quiz → Review → Complete
│   │       ├── /study/kana/[type]/quiz ── 가나 퀴즈
│   │       └── /study/kana/chart ──── 50음도 차트
│   │
│   ├── 💬 /chat ──────────── AI 회화
│   │   ├── /chat ───────────── 회화 메인 (음성통화/텍스트 탭)
│   │   ├── /chat/[id] ──────── 텍스트 채팅 화면
│   │   ├── /chat/[id]/feedback ── 대화 피드백
│   │   ├── /chat/call ──────── 음성통화 화면
│   │   ├── /chat/call/contacts ── 캐릭터 연락처
│   │   └── /chat/call/analyzing ── 통화 분석 중
│   │
│   ├── 👤 /my ────────────── 마이페이지
│   │   ├── /my ─────────────── 프로필 + 업적 + 설정
│   │   └── /my/payments ────── 결제 내역
│   │
│   ├── 💳 /pricing ───────── 요금제 선택
│   └── 💳 /subscription
│       ├── /subscription/checkout ── 결제 (PortOne)
│       └── /subscription/success ── 결제 완료
│
└── 📄 법적 페이지 (legal)
    ├── /terms ─────────────── 이용약관
    └── /privacy ──────────── 개인정보처리방침
```

---

## 네비게이션 구조

### BottomNav (하단 탭바)

```
┌─────────────────────────────────────┐
│  🏠 홈    📊 통계   📚 학습   💬 회화   👤 MY  │
│  /home    /stats   /study   /chat    /my      │
└─────────────────────────────────────┘
```

- 5개 탭 고정 표시
- 활성 탭: 색상 강조 + 하단 언더라인
- 아이콘 선택 시 scale 애니메이션
- 채팅 대화 화면(`/chat/[id]`)에서는 숨김

---

## 공통 레이아웃 정보

### 루트 레이아웃 (`app/layout.tsx`)

- **폰트**: Noto Sans JP (일본어 지원)
- **Provider**: ThemeProvider (next-themes), QueryProvider (TanStack Query)
- **PWA**: 서비스워커 등록
- **Analytics**: Google Analytics

### 앱 그룹 레이아웃 (`(app)/layout.tsx`)

- **컨테이너**: `max-w-lg mx-auto` (모바일 최적화)
- **BottomNav**: 하단 고정
- **ErrorBoundary**: 전역 에러 처리

### 디자인 테마

| 속성 | 값 |
|------|-----|
| 배경색 | `#FFF8F0` (크림색) |
| 주요색 | `#FFB7C5` (벚꽃 핑크) |
| 보조색 | 민트 그린, 스카이 블루 |
| 다크모드 | 지원 (next-themes) |
| 모서리 | 둥근 카드 (rounded-2xl 주로 사용) |
| 애니메이션 | Framer Motion (fade, slide, scale, stagger) |

---

## 문서 사용법

이 문서는 **화면 고도화 작업 시** 다음과 같이 활용합니다:

1. **레이아웃 변경**: 해당 화면의 와이어프레임을 참고하여 섹션 순서/구성 변경 지시
2. **컴포넌트 수정**: "파일 위치" 섹션에서 실제 코드 파일 경로 확인
3. **새 섹션 추가**: 기존 와이어프레임 구조에 맞춰 삽입 위치 지정
4. **AI 지시**: "01-HOME.md의 와이어프레임에서 WeeklyChart를 DailyMissionsCard 위로 이동해줘" 같은 구체적 지시 가능
