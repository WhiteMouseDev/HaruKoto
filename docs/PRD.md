# PRD: 하루코토 (HaruKoto) - 일본어 학습 앱

## 1. 프로젝트 개요

### 1.1 비전

한국인을 위한 재미있는 일본어 학습 앱. JLPT 시험 대비와 실전 회화 능력을 동시에 키울 수 있는 서비스.

### 1.2 서비스명: 하루코토 (HaruKoto / ハルコト)

- **하루**: 한국어 "하루"(1일) + 일본어 "春"(はる, 봄)
- **코토**: 일본어 "言"(こと, 말/단어)
- **의미**: "매일 배우는 단어" + "봄처럼 피어나는 언어"
- **영문**: HaruKoto
- **일본어 표기**: ハルコト

### 1.2 핵심 가치

- **재미**: 게임/퀴즈 + 상황극/스토리로 지루하지 않은 학습
- **실용성**: JLPT 시험 대비 + 실전 회화 능력 향상
- **접근성**: 출퇴근 길에 모바일로 간편하게 학습
- **한국인 특화**: 한일 언어 유사성을 활용한 직관적 학습

### 1.3 타겟 사용자

- 일본어를 처음 배우는 완전 초보 ~ JLPT N1을 준비하는 고급 학습자
- 일본 여행/취업/문화에 관심 있는 한국인
- 출퇴근 시간 등 자투리 시간에 학습하고 싶은 직장인/학생

---

## 2. 기술 스택

### 2.1 프론트엔드

- **Monorepo**: Turborepo + pnpm workspace
- **Framework**: Next.js 16.1 (App Router, Turbopack 기본)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **서버 상태관리**: TanStack Query (React Query)
- **클라이언트 상태관리**: Zustand
- **UI 컴포넌트**: shadcn/ui (Radix UI 기반, 커스터마이징)
- **폼 관리**: React Hook Form + Zod (유효성 검사)
- **테마**: next-themes (라이트/다크 모드, CSS 변수 기반)
- **애니메이션**: Framer Motion
- **패키지 매니저**: pnpm

### 2.2 백엔드

- **API**: Next.js API Routes (Route Handlers)
- **Database**: Supabase (PostgreSQL + Auth + Realtime)
- **AI**: Vercel AI SDK (초기: OpenAI/Gemini → 추후: Claude 도입)
- **ORM**: Prisma

### 2.3 인프라

- **배포**: Vercel
- **스토리지**: Supabase Storage (오디오/이미지)
- **결제**: Stripe 또는 Toss Payments (국내 결제)
- **모니터링**: Vercel Analytics

### 2.4 PWA

- 모바일 퍼스트 반응형 디자인
- Service Worker를 통한 오프라인 지원 (정적 콘텐츠)
- 홈 화면 추가 지원

---

## 3. MVP 기능 정의

### 3.1 사용자 인증 시스템

| 기능               | 설명                              | 우선순위 |
| ------------------ | --------------------------------- | -------- |
| 소셜 로그인        | Google, Kakao, Apple 로그인       | P0       |
| 이메일 회원가입    | 이메일 + 비밀번호 회원가입/로그인 | P0       |
| 프로필 설정        | 닉네임, 레벨 설정                 | P0       |
| 학습 데이터 동기화 | 기기 간 학습 진도 동기화          | P0       |

### 3.2 JLPT 학습 시스템 (무료)

| 기능               | 설명                        | 우선순위 |
| ------------------ | --------------------------- | -------- |
| 레벨 선택          | N5 ~ N1 레벨 선택           | P0       |
| 단어 퀴즈          | 단어 뜻 맞추기, 읽기 맞추기 | P0       |
| 문법 퀴즈          | 문법 패턴 이해도 테스트     | P0       |
| 한자 학습          | 한자 읽기/뜻 퀴즈           | P1       |
| 청해 퀴즈          | 듣기 문제 풀기              | P1       |
| 학습 진도 대시보드 | 전체 진도율, 정답률 통계    | P0       |
| 오답 노트          | 틀린 문제 모아보기 + 복습   | P0       |

### 3.3 게이미피케이션 (무료)

| 기능               | 설명                        | 우선순위 |
| ------------------ | --------------------------- | -------- |
| 포인트/경험치      | 퀴즈 정답 시 경험치 획득    | P0       |
| 레벨업 시스템      | 경험치 누적으로 레벨업      | P0       |
| 연속 학습 (스트릭) | 매일 학습 연속 일수 표시    | P0       |
| 데일리 미션        | 오늘의 학습 목표            | P1       |
| 업적/뱃지          | 특정 조건 달성 시 뱃지 획득 | P2       |

### 3.4 AI 회화 연습 (프리미엄)

| 기능           | 설명                                  | 우선순위 |
| -------------- | ------------------------------------- | -------- |
| 상황극 모드    | 여행/일상/비즈니스 시나리오 기반 대화 | P0       |
| 자유 대화 모드 | AI와 자유 주제로 대화                 | P0       |
| 실시간 피드백  | 문법 오류, 자연스러운 표현 제안       | P0       |
| 대화 번역      | 한국어 ↔ 일본어 번역 지원             | P0       |
| 난이도 조절    | 사용자 레벨에 맞는 대화 난이도        | P1       |
| 대화 기록      | 과거 대화 내역 조회                   | P1       |

### 3.5 상황극 시나리오 카테고리 (MVP)

```
여행/관광
├── 공항/입국
├── 호텔 체크인/체크아웃
├── 식당 주문
├── 길 묻기/교통
└── 관광지/쇼핑

일상생활
├── 편의점/마트
├── 병원/약국
├── 우체국/은행
├── 이웃과의 인사
└── 전화 통화

비즈니스
├── 자기소개/인사
├── 회의
├── 이메일 작성
├── 전화 응대
└── 면접

자유 대화
├── 취미/관심사
├── 일본 문화
├── 시사/뉴스
└── 사용자 정의 주제
```

---

## 4. 수익 모델

### 4.1 무료 (Free Tier)

- JLPT 단어/문법 퀴즈 (전 레벨)
- 기본 게이미피케이션 (포인트, 스트릭, 레벨)
- 학습 진도 대시보드
- 오답 노트

### 4.2 프리미엄 구독 (월정액)

- AI 회화 연습 (무제한)
- 상황극 전체 시나리오
- 자유 대화 모드
- AI 실시간 피드백/교정
- 대화 기록 무제한 저장
- 광고 제거 (추후 무료 티어에 광고 추가 시)

### 4.3 가격 (안)

- 월 구독: ₩9,900
- 연 구독: ₩79,900 (월 ₩6,658, 33% 할인)
- 체험: 프리미엄 기능 3일 무료 체험

---

## 5. 디자인 방향

### 5.1 컨셉

- **귀엽고 친근한** 디자인
- 마스코트 캐릭터 활용 (예: 귀여운 여우/너구리 캐릭터)
- 부드러운 라운드 UI
- 파스텔 톤 + 포인트 컬러

### 5.2 컬러 팔레트 (안)

- Primary: 벚꽃 핑크 (#FFB7C5)
- Secondary: 하늘색 (#87CEEB)
- Accent: 코랄 (#FF6B6B)
- Background: 크림 화이트 (#FFF8F0)
- Text: 다크 그레이 (#2D2D2D)

### 5.3 모바일 퍼스트

- 하단 탭 네비게이션
- 카드 기반 레이아웃
- 큰 터치 타겟 (최소 44px)
- 스와이프 제스처 지원

---

## 6. 데이터베이스 스키마 (핵심)

```
users
├── id (UUID)
├── email
├── nickname
├── avatar_url
├── jlpt_level (N5~N1)
├── experience_points
├── level
├── streak_count
├── last_study_date
├── is_premium
├── subscription_expires_at
├── created_at
└── updated_at

vocabularies
├── id
├── jlpt_level (N5~N1)
├── word (일본어)
├── reading (히라가나)
├── meaning_ko (한국어 뜻)
├── example_sentence
├── example_translation
├── part_of_speech
└── tags

grammars
├── id
├── jlpt_level
├── pattern (문법 패턴)
├── meaning_ko
├── explanation
├── example_sentences (JSON)
└── related_grammar_ids

quiz_results
├── id
├── user_id
├── quiz_type (vocabulary/grammar/kanji/listening)
├── jlpt_level
├── question_id
├── is_correct
├── answered_at
└── time_spent_seconds

conversations
├── id
├── user_id
├── scenario_type
├── scenario_category
├── messages (JSON)
├── feedback_summary
├── created_at
└── ended_at

user_achievements
├── id
├── user_id
├── achievement_type
├── achieved_at
└── metadata (JSON)

daily_missions
├── id
├── user_id
├── date
├── mission_type
├── target_count
├── current_count
├── is_completed
└── reward_claimed
```

---

## 7. 핵심 사용자 플로우

### 7.1 신규 사용자 온보딩

```
앱 접속 → 회원가입/로그인 → 레벨 테스트 (선택) → JLPT 목표 레벨 설정 → 홈 화면
```

### 7.2 JLPT 학습 플로우

```
홈 → JLPT 탭 → 레벨 선택 → 카테고리 선택 (단어/문법) → 퀴즈 풀기 → 결과 확인 → 오답 복습
```

### 7.3 AI 회화 플로우

```
홈 → 회화 탭 → 시나리오 선택 or 자유 대화 → AI와 대화 → 실시간 피드백 → 대화 종료 → 리포트 확인
```

---

## 8. 페이지 구조

```
/ (랜딩 페이지 - 비로그인)
/login (로그인)
/signup (회원가입)
/onboarding (온보딩 - 레벨 설정)

/home (홈 - 대시보드)
  ├── 오늘의 학습 현황
  ├── 스트릭 표시
  ├── 추천 학습
  └── 빠른 시작 버튼

/jlpt (JLPT 학습)
  ├── /jlpt/[level] (레벨별 메인)
  ├── /jlpt/[level]/vocabulary (단어 퀴즈)
  ├── /jlpt/[level]/grammar (문법 퀴즈)
  └── /jlpt/[level]/review (오답 노트)

/conversation (AI 회화) [프리미엄]
  ├── /conversation/scenarios (시나리오 목록)
  ├── /conversation/chat/[id] (대화 화면)
  └── /conversation/history (대화 기록)

/profile (프로필)
  ├── 학습 통계
  ├── 업적/뱃지
  └── 설정

/subscription (구독 관리)
```

---

## 9. MVP 제외 - 로드맵 (추후 확장)

### Phase 2 (MVP 이후 1~2개월)

- [ ] 한자 학습 모듈 (필기 인식)
- [ ] 청해 (듣기) 퀴즈 + TTS
- [ ] 데일리 미션 시스템
- [ ] 업적/뱃지 시스템
- [ ] 소셜 기능 (친구 추가, 랭킹)

### Phase 3 (3~4개월)

- [ ] 오프라인 모드 강화
- [ ] 푸시 알림 (학습 리마인더)
- [ ] Capacitor 래핑 → 앱스토어 배포
- [ ] 단어장 직접 만들기
- [ ] 음성 인식 (발음 평가)

### Phase 4 (5~6개월)

- [ ] 커뮤니티 기능 (Q&A 게시판)
- [ ] 일본어 뉴스/기사 읽기
- [ ] 스터디 그룹
- [ ] 실시간 회화 매칭 (유저 간)
- [ ] 일본어 키보드 연습

### Phase 5 (장기)

- [ ] 다국어 확장 (중국어, 영어 학습자 지원)
- [ ] 기업용 B2B 플랜
- [ ] 교육기관 연동
- [ ] 자격증 과정 (BJT 등)

---

## 10. 기술적 고려사항

### 10.1 AI 비용 관리

- 프리미엄 사용자당 일일 대화 횟수 제한 (예: 30회/일)
- 대화 컨텍스트 길이 관리 (토큰 최적화)
- 시나리오별 시스템 프롬프트 캐싱
- 사용량 모니터링 + 알림

### 10.2 콘텐츠 데이터

- JLPT 단어/문법: 공개 데이터셋 기반 + 직접 검수
- 퀴즈 문제: 직접 제작 + AI 보조 생성
- 상황극 시나리오: 직접 기획 + AI 보조
- 정기적 콘텐츠 업데이트 파이프라인

### 10.3 성능

- ISR (Incremental Static Regeneration) 활용
- 퀴즈 데이터 프리패칭
- 이미지 최적화 (Next.js Image)
- 코드 스플리팅

### 10.4 보안

- API Rate Limiting
- 구독 상태 서버사이드 검증
- XSS/CSRF 방지
- 사용자 데이터 암호화

---

## 11. 성공 지표 (KPI)

### 핵심 지표

- DAU (일일 활성 사용자)
- 평균 학습 시간 (세션당)
- 연속 학습일 (스트릭)
- 퀴즈 정답률 변화
- 무료→프리미엄 전환율
- 구독 유지율 (월간)

### 목표 (출시 후 3개월)

- DAU: 500명
- 평균 세션 시간: 10분 이상
- 프리미엄 전환율: 5%
- 월간 구독 유지율: 70%
