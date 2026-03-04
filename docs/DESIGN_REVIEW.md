# 하루코토 개선 사항 정리

> 최종 업데이트: 2026-03-04
> 코드 대조 검증 완료된 항목만 포함

---

## P0 — 완료

### ~~1. Primary 버튼 색상 접근성~~ ✅
- `primary-foreground`를 `#FFFFFF` → `#5C1A2A`(다크 로즈)로 변경
- 라이트 7.7:1, 다크 5.5:1 — WCAG AA 통과

### ~~2. `userScalable: false` 제거~~ ✅
- `apps/web/src/app/layout.tsx` viewport에서 삭제
- WCAG 1.4.4 (텍스트 크기 조정) 준수

---

## P1 — 이번 스프린트

### 3. Study/Quiz/Result 데이터 페칭 TanStack Query 통일
**현황:** 앱의 5개 탭 중 home/stats/chat/my는 TanStack Query, study/quiz/result만 `useEffect + fetch` 직접 사용.

| 페이지 | 현재 패턴 | 문제 |
|--------|-----------|------|
| `study/page.tsx` | `useEffect + fetch` x2 | 캐싱 없음, `catch {}` 에러 무시 |
| `study/quiz/page.tsx` | `useEffect + fetch` | 캐싱 없음, console.error만 |
| `study/quiz/result/page.tsx` | `useEffect + fetch` | 캐싱 없음, `catch {}` 에러 무시 |

**해결:** `useIncompleteSession`, `useQuizStats`, `useQuizInit`, `useQuizResult` 등 커스텀 훅으로 통일. mutation도 `useMutation`으로 래핑.

### 4. 랜딩 CTA → `/login` 직접 연결
**현황:** `apps/landing/src/app/page.tsx`의 모든 CTA가 `APP_URL`(루트)로 연결.
비로그인 사용자: 랜딩 CTA 클릭 → `app.harukoto.co.kr/` → 인증 체크 → redirect `/login`.

**해결:** CTA `href`를 `APP_URL + '/login'`으로 변경.

### 5. 로그인 "← 처음으로" 링크 수정
**현황:** `apps/web/src/app/(auth)/login/page.tsx`에서 `href="/"`로 이동 → 비로그인 시 다시 인증 체크 → `/login`으로 복귀 (무한 루프).

**해결:** `href="https://www.harukoto.co.kr"`(랜딩 사이트)로 변경.

### 6. BottomNav + 아이콘 버튼 aria-label 추가
**현황:** `bottom-nav.tsx`의 `<nav>`, 각 `<Link>` 모두 `aria-label` 없음. 퀴즈 뒤로가기 버튼, 알림벨 등 아이콘 전용 버튼도 마찬가지.

**해결:**
- `<nav aria-label="메인 네비게이션">`
- 각 탭 `<Link aria-label="홈">`, `<Link aria-label="학습">` 등
- 아이콘 전용 버튼에 `aria-label` 추가

---

## P2 — 다음 스프린트

### 7. 홈 섹션 순서 조정
**현황:** Voice Call CTA가 최상단. 학습 앱의 핵심(매일 학습 진행)이 스크롤해야 보임.

**현재 순서:**
```
Header → Voice Call CTA → Kana CTA → Streak → Daily Progress → Missions → Quick Start → Weekly Chart → Level
```

**권장 순서:**
```
Header → Streak → Daily Progress → Missions → Kana CTA → Quick Start → Weekly Chart → Voice Call CTA → Level
```

### 8. 에러 바운더리 섹션 격리
**현황:** `(app)/layout.tsx`에 전체 레벨 ErrorBoundary 하나만 존재. 홈의 WeeklyChart나 DailyMissions 등 개별 컴포넌트 에러 시 전체 페이지 사망.

**해결:** 독립적인 데이터를 쓰는 섹션마다 개별 ErrorBoundary로 감싸서 부분 실패 허용.

### 9. 프로필 사진 업로드
**현황:** Avatar가 항상 fallback(UserIcon). Supabase Storage 사용 가능하나 업로드 UI 미구현.

### 10. 로그인 페이지 로딩 중 소셜 버튼 비활성화
**현황:** `handleEmailAuth` 처리 중에도 소셜 로그인 버튼 클릭 가능. 동시 인증 요청 가능.

**해결:** 로딩 상태일 때 소셜 로그인 버튼도 `disabled` 처리.

---

## P3 — 향후

### 11. N3~N1 "준비 중" 뱃지 통일
온보딩에서는 비활성 레벨에 "준비 중" 뱃지가 있지만 Study 탭에서는 `opacity-40`만 적용.

### 12. 퀴즈 `confirm()` → 커스텀 다이얼로그
브라우저 네이티브 confirm이 앱 디자인과 불일치.

### 13. 퀴즈 결과에 소요 시간 표시
퀴즈 중 timer는 있지만 결과 화면으로 전달되지 않음.

### 14. 오답 목록 기본 펼침
퀴즈 결과에서 틀린 문제 3개 이하면 기본 펼침으로 변경.

### 15. `LazyMotion`으로 Framer Motion 최적화
모든 페이지에서 framer-motion 전체 import. `LazyMotion + domAnimation`으로 번들 크기 절약.
