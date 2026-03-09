# 레벨 시스템 개편 계획

## 배경

현재 앱은 JLPT 레벨을 하드 필터로 사용하여 콘텐츠를 제한하고 있음.
다양한 수준의 유저가 유입되는 상황에서 N5 고정은 비합리적.
가나 학습도 N5 유저에게만 노출되어 유연성이 부족함.

## 현재 문제점

### 1. JLPT 레벨 제한
- 온보딩에서 N5만 선택 가능 (N4~N1 "준비 중")
- 학습 탭에서 N5, N4만 활성화
- 이미 아는 유저도 N5부터 시작해야 함 → 이탈 위험

### 2. 가나 학습 노출
- N5 유저에게만 홈/학습 탭에 가나 CTA 표시
- 가나를 이미 아는 N5 초보자도 가나 카드를 봐야 함
- N4+ 유저가 가나를 복습하고 싶어도 접근 경로 없음
- 온보딩 후 N5면 무조건 `/study/kana`로 리다이렉트

---

## Phase 1: 온보딩 개편 + 가나 토글

### 1-1. 온보딩 레벨 선택 전면 개방
- N5~N1 전부 선택 가능하게 변경
- "준비 중" 뱃지 제거
- 각 레벨 설명 개선:
  - N5: 완전 초보 — 히라가나부터 시작
  - N4: 기초 — 기본 문법과 단어를 알아요
  - N3: 중급 — 일상 회화가 가능해요
  - N2: 중상급 — 뉴스/소설을 읽을 수 있어요
  - N1: 상급 — 네이티브에 가까워요

### 1-2. 온보딩에 가나 질문 추가
- 레벨 선택 후 (N5 선택 시) 추가 질문:
  - "히라가나/가타카나부터 배워볼까요?"
  - 선택지: `네, 기초부터 배울래요` / `건너뛸게요`
- `네, 기초부터 배울래요` → `showKana: true` 저장, 온보딩 후 `/study/kana`로 이동
- `건너뛸게요` → `showKana: false` 저장, `/home`으로 이동
- N4~N1 선택 시 → 가나 질문 스킵, `showKana: false`

### 1-3. User 모델에 `showKana` 필드 추가
```prisma
showKana Boolean @default(false) @map("show_kana")
```

### 1-4. 마이페이지 설정에 가나 학습 토글 추가
- "가나 학습 표시" ON/OFF 스위치
- ON → 홈/학습 탭에 가나 섹션 표시
- OFF → 가나 섹션 숨김
- 가나를 다시 복습하고 싶을 때 켤 수 있음

### 1-5. 가나 노출 로직 변경
- 현재: `jlptLevel === 'N5' && kanaProgress < 100%`
- 변경: `showKana === true && kanaProgress < 100%`
- 가나 100% 완료 시 자동으로 `showKana = false`로 업데이트 + 토스트 안내

### 변경 파일
| 파일 | 변경 |
|------|------|
| `packages/database/prisma/schema.prisma` | `showKana` 필드 추가 |
| `apps/web/src/app/(auth)/onboarding/page.tsx` | 레벨 전면 개방 + 가나 질문 스텝 추가 |
| `apps/web/src/app/api/v1/auth/onboarding/route.ts` | `showKana` 저장 |
| `apps/web/src/app/(app)/home/page.tsx` | 가나 CTA 조건 변경 |
| `apps/web/src/app/(app)/study/page.tsx` | 가나 배너 조건 변경 |
| `apps/web/src/components/features/my/settings-menu.tsx` | 가나 토글 추가 |
| `apps/web/src/app/api/v1/user/profile/route.ts` | `showKana` PATCH 지원 |
| `apps/web/src/app/api/v1/stats/dashboard/route.ts` | `showKana` 반환 |

---

## Phase 2: 학습 탭 레벨 자유 선택

### 2-1. 학습 탭 레벨 잠금 해제
- N3, N2, N1 "준비 중" 제거 → 전부 활성화
- 컨텐츠 없는 레벨은 "콘텐츠 준비 중" 안내 (빈 퀴즈 방지)

### 2-2. 퀴즈 출제 시 컨텐츠 유무 체크
- `quiz/start` API에서 해당 레벨 단어/문법 수 확인
- 0개이면 에러 대신 "이 레벨의 콘텐츠를 준비하고 있어요" 응답

### 2-3. 추천 시스템 레벨 반영
- `quiz/recommendations` 하드코딩 N5 → 유저 레벨 사용

### 변경 파일
| 파일 | 변경 |
|------|------|
| `apps/web/src/app/(app)/study/page.tsx` | 모든 레벨 활성화 |
| `apps/web/src/app/api/v1/quiz/start/route.ts` | 컨텐츠 유무 체크 |
| `apps/web/src/app/api/v1/quiz/recommendations/route.ts` | N5 하드코딩 제거 |

---

## Phase 3: N4~N1 컨텐츠 시딩

### 3-1. 단어 데이터
- N4 단어 (~700개), N3 (~1,800개) 시드 데이터 준비
- N2, N1은 추후 추가

### 3-2. 문법 데이터
- N4 문법 (~130개), N3 문법 (~180개) 시드
- Cloze, SentenceArrange 문제도 레벨별 생성

### 3-3. AI 회화 레벨 프롬프트
- 각 레벨별 시스템 프롬프트 작성 (이미 구조는 존재)
- N4: 기본 경어, 일상 주제
- N3: 다양한 문법, 사회적 주제
- N2+: 뉴스/비즈니스 주제

---

## 우선순위

```
Phase 1 (온보딩 + 가나 토글) ← 지금 개발
Phase 2 (학습 탭 개방)       ← Phase 1 직후
Phase 3 (컨텐츠 시딩)        ← 별도 작업
```

Phase 1, 2는 코드 변경만으로 가능. Phase 3은 데이터 작업이 필요.
