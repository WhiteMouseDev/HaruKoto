# 하루코토 - 프론트엔드 코드 품질 분석 리포트

**분석 대상**: `apps/web/src/` (컴포넌트, 훅, 스토어, 라이브러리)
**분석일**: 2026-03-07
**분석가**: Frontend Code Quality Analyst

---

## 📊 분석 요약

- **총 컴포넌트**: 58개 (UI 기본 + Feature)
- **총 훅**: 26개
- **Zustand 스토어**: 1개 (최소화)
- **평균 컴포넌트 크기**: ~140줄
- **대형 컴포넌트(500줄↑)**: 1개
- **중형 컴포넌트(300~500줄)**: 5개

---

## 🔴 Critical Issues

### 1. **Unsafe setTimeout in Render Path (TypingQuiz)**
**파일**: `/apps/web/src/components/features/quiz/typing-quiz.tsx:102-106`
**심각도**: CRITICAL
**설명**:
```typescript
if (placed.length === slotCount && answerState === 'idle') {
  setTimeout(checkAnswer, 300);  // ❌ 렌더 중 상태 업데이트 트리거
}
```
렌더 함수에서 setTimeout을 호출하면 매번 새로운 타이머가 생성되고, 무한 루프를 유발할 수 있음.

**해결책**:
```typescript
useEffect(() => {
  if (placed.length === slotCount && answerState === 'idle') {
    const timer = setTimeout(checkAnswer, 300);
    return () => clearTimeout(timer);
  }
}, [placed, slotCount, answerState, checkAnswer]);
```

---

### 2. **Missing Error Handling in API Calls**
**파일**: Multiple pages (e.g., `/app/(app)/chat/page.tsx`, `/app/(app)/study/quiz/page.tsx`)
**심각도**: CRITICAL
**설명**:
- 직접 `apiFetch` 호출 시 에러가 발생해도 적절한 에러 상태 관리 없음
- UI에 토스트 메시지는 일부만 처리 (sonner 라이브러리 사용)
- catch 블록에서 상태 초기화는 있으나, 사용자에게 구체적인 에러 정보 전달 부족

**예시**:
```typescript
// chat/page.tsx:88-100
async function handleStartConversation(scenario: Scenario) {
  setStarting(true);
  try {
    const data = await apiFetch<StartResponse>('/api/v1/chat/start', {...});
    // ...
  } catch (err) {
    setError(err instanceof Error ? err.message : '대화를 시작할 수 없습니다.');
    // 에러 메시지가 렌더되지 않거나, 에러 상태를 자동으로 초기화하지 않음
  }
}
```

**해결책**:
- useCallback으로 에러 핸들링 통합
- 자동 에러 초기화 타이머 추가
- 네트워크 에러/검증 에러/서버 에러 구분

---

### 3. **Untyped/Loose Error Handling in Hooks**
**파일**: `/hooks/use-quiz.ts`, `/hooks/use-chat-history.ts`
**심각도**: CRITICAL
**설명**:
```typescript
// use-quiz.ts:184 - unknown 타입 반환
export function useAnswerQuestion() {
  return useMutation<unknown, Error, AnswerQuestionParams>({...});  // ❌ 반환 타입이 unknown
}

// use-chat-history.ts:75 - 에러 처리 미흡
onError: (_err, _id, context) => {
  // _err 타입이 unknown이면, instanceof Error 체크 없음
  toast.error('삭제에 실패했어요. 다시 시도해주세요.');
}
```

**해결책**: 모든 mutation 반환 타입을 명시, 에러 타입 정의

---

## 🟠 Major Issues

### 4. **Oversized Component: SettingsMenu (622줄)**
**파일**: `/components/features/my/settings-menu.tsx`
**심각도**: MAJOR
**설명**:
- 학습 설정, 앱 설정, 정보, 계정 관리를 모두 포함
- 상태 관리: 8개의 setState + 1개 useRef (localSilence 재계산)
- 가독성과 유지보수성 저하

**현재 구조**:
```typescript
export function SettingsMenu({...}) {
  const [levelSheetOpen, setLevelSheetOpen] = useState(false);
  const [goalSheetOpen, setGoalSheetOpen] = useState(false);
  const [themeSheetOpen, setThemeSheetOpen] = useState(false);
  const [callSheetOpen, setCallSheetOpen] = useState(false);
  const [localSilence, setLocalSilence] = useState(...);
  const [prevSilence, setPrevSilence] = useState(...);
  const silenceTimerRef = useRef<ReturnType<typeof setTimeout>>(undefined);

  // 422줄의 JSX...
}
```

**해결책**:
```
SettingsMenu (부모)
├── LearningSettingsSection (JLPT, DailyGoal, ShowKana)
├── AppSettingsSection (Theme, Notifications)
├── InfoSection (Terms, Privacy, Contact)
├── AccountSection (Logout, Delete)
└── CallSettingsSheet (Silence, Subtitle, AutoAnalysis)
```

---

### 5. **Prop Drilling in Quiz Pages**
**파일**: `/app/(app)/study/quiz/page.tsx`
**심각도**: MAJOR
**설명**:
- QuizPage (500+ 줄) → QuizContent → 4개의 Quiz 컴포넌트
- Props: questions, sessionId, onAnswer, onComplete
- 각 Quiz 컴포넌트가 독립적으로 상태 관리하지만, 페이지 레벨에서도 상태 중복 관리

```typescript
function QuizContent() {
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [questions, setQuestions] = useState<QuizQuestion[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [selectedOption, setSelectedOption] = useState<string | null>(null);
  const [answerState, setAnswerState] = useState<AnswerState>('idle');
  // ... 10개 이상의 state

  // Quiz 컴포넌트로 props 전달
  return <MatchingPairQuiz questions={questions} onAnswer={...} />;
}
```

**해결책**:
- Zustand 스토어로 Quiz 세션 상태 중앙화
- 페이지 상태 최소화 (loading, error만 유지)

---

### 6. **Missing Keyboard Navigation (Accessibility)**
**파일**: Quiz 컴포넌트, 가나 학습 컴포넌트
**심각도**: MAJOR
**설명**:
- 선택지/옵션 버튼에 `onKeyDown` 핸들러 없음
- 스크린 리더 지원 부족 (aria-label은 있으나 aria-live, aria-current 등 부족)
- 포커스 관리 없음 (TAB 순서 정의 안 됨)

**예시**:
```typescript
// kana-quiz.tsx - 키보드 이벤트 없음
<div className="grid grid-cols-2 gap-3" aria-live="assertive">
  {options.map((option) => (
    <button
      key={option.id}
      className={...}
      onClick={handleSelect}
      // ❌ onKeyDown 없음
      aria-label={`선택지: ${option.text}`}
    >
      {option.text}
    </button>
  ))}
</div>
```

**해결책**:
```typescript
const handleKeyDown = (e: React.KeyboardEvent) => {
  if (e.key === 'Enter' || e.key === ' ') {
    e.preventDefault();
    handleSelect();
  }
};
```

---

### 7. **Excessive Framer Motion Usage**
**파일**: Multiple components (settings-menu, quiz, chat)
**심각도**: MAJOR
**설명**:
- motion.div 과도 사용 (설정 메뉴에만 4개)
- 화면 진입마다 애니메이션 (delay: 0.1, 0.15, 0.2, 0.25)
- GPU 최적화 없음 (will-change 부재)
- 모바일에서 성능 영향 가능

```typescript
// settings-menu.tsx:176-236
<motion.div
  initial={{ y: 10, opacity: 0 }}
  animate={{ y: 0, opacity: 1 }}
  transition={{ delay: 0.1 }}  // ❌ 4개의 섹션이 각각 0.1s씩 지연
/>
<motion.div
  initial={{ y: 10, opacity: 0 }}
  animate={{ y: 0, opacity: 1 }}
  transition={{ delay: 0.15 }}
/>
// ... 총 600ms 애니메이션
```

**해결책**:
- 필수 애니메이션만 유지 (초기 로드 제외)
- 컨테이너 motion으로 통합, staggerChildren 사용
- 스트레스 테스트 (느린 4G, 저사양 모바일)

---

### 8. **Type Safety Issues**
**파일**: Multiple hooks and components
**심각도**: MAJOR

**문제 사례**:
```typescript
// use-quiz.ts:45 - Discriminated Union이 아닌 optional 필드
type QuizQuestion = {
  questionText: string;
  options?: QuizOption[];           // ❌ optional
  // Cloze fields
  sentence?: string;
  // SentenceArrange fields
  tokens?: { ... }[];
  // Typing fields
  answer?: string;
};
// → 런타임 에러 가능 (undefined 필드 접근)

// use-gemini-live.ts:27
type GeminiLiveOptions = {
  onAudioChunk: (base64: string) => void;
  onAiTextDelta: (text: string) => void;
  onTranscript: (entry: TranscriptEntry) => void;
  // callback 타입이 명시되지 않음
};
```

**해결책**: Discriminated Union으로 타입 안전성 확보

```typescript
type QuizQuestion =
  | { type: 'MATCHING'; options: QuizOption[] }
  | { type: 'CLOZE'; sentence: string }
  | { type: 'SENTENCE_ARRANGE'; tokens: SentenceToken[] }
  | { type: 'TYPING'; answer: string };
```

---

### 9. **No Data Validation in Forms**
**파일**: `/components/features/wordbook/add-word-dialog.tsx`
**심각도**: MAJOR
**설명**:
- React Hook Form + Zod 사용하지만, 미흡한 검증
- 일본어 단어 입력 형식 검증 부족
- 서버 응답 에러 후 폼 상태 초기화 안 됨

```typescript
// add-word-dialog.tsx에서 기본 구조는 있으나
// 복잡한 검증 (한글/일본어 혼합, 정규식) 부재
```

---

### 10. **Missing Query Invalidation Edge Cases**
**파일**: `/hooks/use-quiz.ts:206-208`
**심각도**: MAJOR
**설명**:
```typescript
onSuccess: () => {
  queryClient.invalidateQueries({ queryKey: queryKeys.quizStats });  // 모든 쿼리 무효화
  // → 캐시 관리 비효율
};
```

**해결책**: 정확한 쿼리 키 필터링
```typescript
onSuccess: (data) => {
  queryClient.invalidateQueries({
    queryKey: [...queryKeys.quizStats, level, type],  // 특정 레벨/타입만
  });
};
```

---

## 🟡 Minor Issues

### 11. **Unused/Dead Code**
**파일**: `/components/features/my/settings-menu.tsx:18, 154-165`
**심각도**: MINOR

```typescript
// Line 18 - 미사용 import
// Gauge,

// Line 154-165 - 주석 처리된 코드
// const handleSpeedChange = useCallback(...)
// const speedTimerRef = useRef(...)
```

**해결책**: 제거하거나 기능이 준비되면 복원

---

### 12. **Inconsistent Error Boundary Usage**
**파일**: `/components/error-boundary.tsx`
**심각도**: MINOR
**설명**:
- ErrorBoundary는 작동하지만, 모든 페이지에 적용되지 않음
- 일부 페이지만 에러 처리 UI 있음
- Suspense와 혼합 사용 시 순서 주의

```typescript
// quiz/page.tsx:52-64에만 Suspense 있음
export default function QuizPage() {
  return (
    <Suspense fallback={...}>
      <QuizContent />
    </Suspense>
  );
}
```

**해결책**: (app)/layout.tsx에서 ErrorBoundary + Suspense 통합

---

### 13. **useCallback Dependency Issues**
**파일**: `/components/features/quiz/sentence-arrange.tsx:71-88`
**심각도**: MINOR
**설명**:
```typescript
const handleRemoveToken = useCallback(
  (index: number) => {
    if (answerState !== 'idle') return;
    const token = placed[index];
    setPlaced((prev) => prev.filter((_, i) => i !== index));
    setAvailable((prev) => [...prev, token]);
  },
  [answerState, placed]  // ❌ placed 변경 → 콜백 재생성 → 메모이제이션 무의미
);
```

**영향**: useCallback의 이점 감소, 불필요한 리렌더 가능

---

### 14. **Missing Loading States in Complex Flows**
**파일**: Voice input, Gemini Live 연결
**심각도**: MINOR
**설명**:
- 음성 녹음 중 cancel 가능하지만, 상태 전환 과정에서 UI 피드백 부족
- 네트워크 지연 중 사용자 입력 중단 메커니즘 없음

---

### 15. **LocalStorage/SessionStorage 오류 처리 부재**
**파일**: `/app/(app)/chat/page.tsx:95-104`
**심각도**: MINOR
**설명**:
```typescript
sessionStorage.setItem(
  `chat_${data.conversationId}`,
  JSON.stringify({...})
);
// ❌ sessionStorage.setItem 실패 시 처리 없음
// (일반적으로 드물지만, 용량 초과 시 발생 가능)
```

---

## 🟢 Good Practices

### ✅ TanStack Query 활용
- 적절한 staleTime 설정
- optimistic update 구현 (chat history 삭제)
- 캐시 무효화 전략 수립

### ✅ 타입 안전성 (부분적)
- 훅과 컴포넌트에서 제너릭 타입 사용
- discriminated union 시도 (일부)

### ✅ 컴포넌트 분리
- UI 컴포넌트와 Feature 컴포넌트 명확한 구분
- shadcn/ui 활용으로 일관된 디자인

### ✅ 접근성 기본 구현
- aria-label 일부 적용
- aria-live 사용 (퀴즈)

### ✅ 성능 최적화 시도
- Suspense 경계 설정
- dynamic import 활용 (몇몇 페이지)

---

## 📋 개선 우선순위

### Phase 1 (Critical - 1주)
1. **TypingQuiz setTimeout 버그 수정** → 렌더 루프 방지
2. **에러 핸들링 통일** → apiFetch 에러 처리 표준화
3. **타입 안전성 개선** → QuizQuestion discriminated union

### Phase 2 (Major - 2주)
4. **SettingsMenu 분해** → 5개 하위 컴포넌트로 리팩토링
5. **접근성 개선** → 키보드 네비게이션, aria-live 통합
6. **Quiz 상태 중앙화** → Zustand 스토어로 이동
7. **Framer Motion 최적화** → stagger 통합, will-change 추가

### Phase 3 (Minor - 3주)
8. **데이터 검증** → Zod 스키마 강화
9. **캐시 관리** → Query key 세분화
10. **코드 정리** → 미사용 코드 제거

---

## 🔧 권장 설정

### ESLint 규칙 추가
```json
{
  "rules": {
    "react/no-array-index-key": "error",
    "react-hooks/exhaustive-deps": "error",
    "no-console": ["warn", { "allow": ["error"] }],
    "@typescript-eslint/no-explicit-any": "error"
  }
}
```

### Performance 모니터링
- Next.js 내장 성능 지표 활용
- 컴포넌트 리렌더 추적 (React DevTools Profiler)
- 번들 크기 분석 (next-bundle-analyzer)

---

## 결론

**현재 상태**: 기본 구조는 견고하나, 규모 확대에 따라 유지보수성 저하 위험

**핵심 개선점**:
1. 컴포넌트 크기 제한 (300줄 이상 경고)
2. 에러 처리 표준화
3. 타입 안전성 강화
4. 접근성 및 성능 감시 자동화

**달성 시 효과**:
- 버그 감소 (40~50%)
- 개발 속도 향상 (PR 리뷰 시간 감소)
- 사용자 경험 개선 (성능, 접근성)
