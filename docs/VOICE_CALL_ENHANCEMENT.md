# 음성통화 기능 고도화 설계 문서

> **상태**: 설계 완료 / 구현 전
> **최종 업데이트**: 2026-03-04
> **관련 문서**: `VOICE_CHAT_DESIGN.md`, `VOICE_CALL_ANALYSIS.md`

---

## 1. 현재 상태 분석

### 핵심 기술 스택

- **Gemini Live API** (WebSocket) — 실시간 양방향 음성 스트리밍
- **모델**: `gemini-2.5-flash-native-audio-preview-12-2025`
- **음성**: `Kore` (일본어 여성)
- **오디오**: 입력 16kHz PCM / 출력 24kHz PCM
- **자동 음성 감지 (VAD)**: `silenceDurationMs: 1200` (현재 고정)

### 현재 통화 플로우

```
회화탭 → 통화 CTA → /chat/call (통화 화면, 뒤로가기 없음)
  → 시작 버튼 → Gemini WebSocket 연결 → 실시간 통화
  → 종료 → /chat/call/analyzing → /chat/{id}/feedback
```

### 주요 문제점

1. **UX**: 통화 화면에 뒤로가기 버튼 없음 — 통화 시작 후 종료만 가능
2. **확장성**: 하루(Haru) 한 캐릭터만 존재, 추가 캐릭터 구조 없음
3. **개인화**: 침묵 대기 시간 등 유저별 설정 불가
4. **복습 연계**: 피드백의 추천 표현/교정을 학습 시스템과 연결하는 기능 없음

---

## 2. 고도화 목표

### 핵심 차별화 포인트

> **"전화 통화하듯 자연스럽게 일본어를 배운다"**

- 실제 전화 통화와 동일한 UX
- 통화 후 상세 피드백 + 즉시 복습
- 레벨에 맞는 개인화된 통화 경험

### 우선순위

| 순위 | 항목 | 설명 |
|------|------|------|
| P0 | 통화 UX 개선 | 연락처 UI + 뒤로가기 + 플로우 정리 |
| P0 | 통화 설정 | 침묵 시간, 자막, 분석 ON/OFF, AI 속도 |
| P1 | 피드백 복습 연계 | 추천 표현 플래시카드 + 단어장 저장 |
| P2 | 캐릭터 시스템 | 다중 캐릭터 DB 모델 + 해금 시스템 |

---

## 3. 통화 플로우 개선

### 3.1 새로운 플로우

```
회화탭 [음성통화 서브탭]
  └─ 통화 CTA 클릭
      └─ /chat/call/contacts (연락처 목록)
          └─ 캐릭터 선택
              └─ /chat/call?characterId=xxx (통화 화면, 뒤로가기 가능)
                  ├─ 시작 전: 캐릭터 정보 + 통화 시작 버튼 + ← 뒤로가기
                  ├─ 통화 중: 기존 통화 UI
                  └─ 종료 후: 분석 → 피드백
```

### 3.2 연락처 화면 (`/chat/call/contacts`)

아이폰 연락처 스타일의 캐릭터 목록 화면.

```
┌────────────────────────────┐
│  ← 연락처                   │
│                            │
│  ╭─────╮                   │
│  │     │  하루 (はる)       │
│  │ 🦊  │  친절한 친구       │
│  │     │  카주얼 · 초급~중급 │
│  ╰─────╯                   │
│                            │
│  ╭─────╮                   │
│  │     │  유키 (ゆき)       │
│  │ 🔒  │  엄격한 선생님     │
│  │     │  N4 도달 시 해금    │
│  ╰─────╯                   │
│                            │
│  ╭─────╮                   │
│  │     │  리코 (りこ)       │
│  │ 🔒  │  비즈니스 동료     │
│  │     │  N3 도달 시 해금    │
│  ╰─────╯                   │
│                            │
└────────────────────────────┘
```

**특징:**
- 헤더에 `←` 뒤로가기 버튼 (회화탭으로 복귀)
- 캐릭터 아바타 + 이름(일본어) + 설명 + 난이도
- 잠긴 캐릭터는 해금 조건 표시 (반투명 + 자물쇠)
- 캐릭터 탭 → 바로 통화 화면으로 이동

### 3.3 통화 화면 개선 (`/chat/call`)

**idle 상태 변경:**
- `←` 뒤로가기 버튼 추가 (연락처 목록으로 복귀)
- 캐릭터 이름/설명 표시
- 기본 모드: **자유 대화** (시나리오 선택 없음)

```
┌────────────────────────────┐
│  ←                         │
│                            │
│         (하루 아바타)        │
│         ハル                │
│         하루                │
│                            │
│    「친절한 친구와의 전화」    │
│                            │
│         ╭──────╮           │
│         │  📞  │           │
│         ╰──────╯           │
│    탭하여 통화 시작           │
│                            │
└────────────────────────────┘
```

---

## 4. 캐릭터 시스템

> **📄 상세 문서**: [`CHARACTER_SYSTEM.md`](./CHARACTER_SYSTEM.md)
>
> 캐릭터 시스템의 전체 기획(8명 캐릭터 상세, Gemini 음성 매칭, DB 모델, 시스템 프롬프트 가이드)은
> 별도 문서로 분리되었습니다.

### 4.1 현재 → 추후 확장 전략

**Phase 0 (지금):** 하루만 유지, UI 구조만 연락처 스타일로 변경
**Phase 1 (추후):** DB 모델 추가 + 캐릭터 8명 구현 (기본 2 + 티어별 6)

### 4.2 캐릭터 구성 요약

| 티어 | 해금 | 남성 | 여성 | 말투 |
|------|------|------|------|------|
| 기본 | 없음 | 🐺 소라 | 🦊 하루 | タメ語 |
| 초급 | N4 | 🐕 카이토 | 🐱 유키 | です・ます |
| 중급 | N3 | 🐾 렌 | 🦋 미오 | 비즈니스 |
| 고급 | N2 | 🦅 리쿠 | 🌸 아오이 | 敬語 |

### 4.3 해금 조건

```typescript
type UnlockCondition = 'N4' | 'N3' | 'N2' | null;

function isCharacterUnlocked(
  condition: UnlockCondition,
  userJlptLevel: string
): boolean {
  if (!condition) return true; // 기본 캐릭터

  const levelOrder = ['N5', 'N4', 'N3', 'N2', 'N1'];
  const userIdx = levelOrder.indexOf(userJlptLevel);
  const requiredIdx = levelOrder.indexOf(condition);

  return userIdx >= requiredIdx;
}
```

---

## 5. 통화 설정 시스템

### 5.1 마이페이지 > 통화 설정

```
┌────────────────────────────┐
│  통화 설정                   │
│                            │
│  침묵 대기 시간              │
│  말을 멈춘 후 AI가 응답하기  │
│  까지의 대기 시간            │
│  [────●──────] 2.0초       │
│  짧게 (1초)     길게 (5초)  │
│                            │
│  AI 응답 속도               │
│  [────●──────] 보통        │
│  느리게          빠르게      │
│                            │
│  자막 표시                  │
│  AI가 말하는 내용을 자막으로  │
│  표시합니다                  │
│  [ON ●───] (토글)           │
│                            │
│  통화 후 자동 분석           │
│  통화 종료 후 AI 피드백을    │
│  자동으로 생성합니다          │
│  [ON ●───] (토글)           │
│                            │
└────────────────────────────┘
```

### 5.2 설정 저장

유저 프로필에 통화 설정을 JSON으로 저장.

```prisma
// User 모델에 추가
callSettings Json? @default("{}") @map("call_settings")
```

```typescript
type CallSettings = {
  silenceDurationMs: number;   // 1000~5000, 기본값은 JLPT 레벨에 따라 결정
  aiResponseSpeed: number;     // 0.8~1.2 배속 (Gemini 설정)
  subtitleEnabled: boolean;    // 자막 ON/OFF, 기본 true
  autoAnalysis: boolean;       // 통화 후 자동 분석, 기본 true
};

// JLPT 레벨별 기본 침묵 시간
const DEFAULT_SILENCE_BY_LEVEL: Record<string, number> = {
  N5: 3000,  // 3초 — 초보자는 생각할 시간 필요
  N4: 2500,  // 2.5초
  N3: 2000,  // 2초
  N2: 1500,  // 1.5초
  N1: 1200,  // 1.2초 — 고급자는 자연스러운 대화 템포
};
```

### 5.3 Gemini Live 설정 적용

```typescript
// use-gemini-live.ts에서 설정 반영
const config = {
  realtimeInputConfig: {
    automaticActivityDetection: {
      startOfSpeechSensitivity: 'HIGH',
      endOfSpeechSensitivity: 'LOW',
      prefixPaddingMs: 300,
      silenceDurationMs: callSettings.silenceDurationMs, // 유저 설정 반영
    },
  },
};
```

---

## 6. 피드백 복습 연계

### 6.1 피드백 페이지 내 플래시카드 섹션

통화 후 피드백 페이지 하단에 **추천 표현 플래시카드** 추가.

```
┌────────────────────────────┐
│  피드백 페이지               │
│                            │
│  ★ 4.2 점수 / 교정 내역     │
│  ...                        │
│                            │
│  ━━━━━━━━━━━━━━━━━━━━━━━━  │
│                            │
│  📚 추천 표현 학습           │
│                            │
│  ┌──────────────────────┐  │
│  │                      │  │
│  │  「お勧めは何ですか」  │  │
│  │                      │  │
│  │    탭하여 뒤집기       │  │
│  │                      │  │
│  │  ──────────────────  │  │
│  │  (뒤집으면)           │  │
│  │  추천은 뭐예요?       │  │
│  │  [1/3]               │  │
│  └──────────────────────┘  │
│                            │
│  ← 이전    [알겠다] [모르겠다]    다음 →  │
│                            │
│  [전체 단어장에 저장하기]    │
│                            │
└────────────────────────────┘
```

**동작:**
- 추천 표현(`recommendedExpressions`)을 플래시카드로 표시
- 탭하면 뒤집기 (일본어 → 한국어 번역)
- "알겠다/모르겠다" 버튼으로 자기 평가
- "단어장에 저장하기" → 내 단어장에 추가
- 교정 내용(`corrections`)도 같은 형태로 학습 가능

### 6.2 단어장 저장 API

```typescript
// POST /api/v1/wordbook
// 기존 단어장 API를 활용하여 추천 표현 저장
{
  word: "お勧め",
  reading: "おすすめ",
  meaning: "추천",
  exampleSentence: "お勧めは何ですか",
  exampleMeaning: "추천은 뭐예요?",
  source: "voice_call_feedback", // 출처 표시
  conversationId: "uuid"         // 통화 연결
}
```

### 6.3 교정 내용 → 오답노트 연계

통화 피드백의 `corrections`(문법/어휘 오류)를 오답노트에 저장하여 나중에 복습.

```typescript
// 교정 데이터 구조 (기존)
type Correction = {
  original: string;    // 유저가 말한 것
  corrected: string;   // 올바른 표현
  explanation: string; // 한국어 설명
};

// 오답노트에 저장 시:
// - original = 유저 답변
// - corrected = 정답
// - explanation = 해설
// - source = 'voice_call'
```

---

## 7. 구현 로드맵

### Phase 0: UX 핫픽스 (즉시)

> 통화 화면 진입/이탈 문제 해결

1. 통화 화면(`/chat/call`) idle 상태에 **← 뒤로가기 버튼** 추가
2. 뒤로가기 시 연락처 또는 회화탭으로 복귀

### Phase 1: 연락처 UI + 통화 설정 (1주)

1. `/chat/call/contacts` 연락처 페이지 생성
   - 하루 캐릭터 1명만 (하드코딩 OK, DB 모델은 Phase 3)
   - 잠긴 캐릭터 2명은 "Coming Soon" 표시
2. 회화탭 음성통화 CTA → 연락처 페이지로 연결
3. 홈 CTA → 연락처 페이지로 연결
4. 마이페이지에 통화 설정 섹션 추가
   - 침묵 대기 시간 슬라이더
   - AI 응답 속도 슬라이더
   - 자막 표시 토글
   - 통화 후 자동 분석 토글
5. User 모델에 `callSettings` JSON 필드 추가
6. 통화 시 유저 설정값을 Gemini Live에 반영

### Phase 2: 피드백 복습 연계 (1주)

1. 피드백 페이지에 추천 표현 플래시카드 섹션 추가
2. "단어장에 저장하기" 기능 연결 (기존 wordbook API 활용)
3. 교정 내용을 오답노트에 저장하는 기능
4. 피드백 내 "이 표현 연습하기" → 미니 플래시카드 UI

### Phase 3: 캐릭터 시스템 (추후) → [상세: CHARACTER_SYSTEM.md](./CHARACTER_SYSTEM.md)

1. `AiCharacter` DB 모델 추가 + 마이그레이션 (gender, tier 등 확장 필드 포함)
2. 캐릭터 8명 시드 데이터 (기본 2 + 초급 2 + 중급 2 + 고급 2)
3. 연락처 페이지를 DB 기반으로 전환
4. 캐릭터별 시스템 프롬프트, 음성, 침묵 시간 적용
5. 해금 로직 구현 (JLPT 레벨 기반, 4티어)
6. Gemini Live 음성 옵션 확장 (캐릭터별 voiceName — 8개 음성 매칭)

### Phase 4: 통화 통계/기록 (추후)

1. 통화 기록 대시보드 (통화 횟수, 총 시간, 평균 점수)
2. 실력 변화 그래프 (통화별 점수 추이)
3. 캐릭터별 통화 통계

---

## 8. 기술 구현 세부사항

### 8.1 침묵 대기 시간 적용 경로

```
마이페이지 설정 변경
  → POST /api/v1/user/call-settings
  → User.callSettings JSON 업데이트
  → 통화 시작 시 useVoiceCall에서 설정 로드
  → useGeminiLive.connect()에 silenceDurationMs 전달
  → Gemini Live WebSocket config에 반영
```

### 8.2 자막 표시 설정 적용

```typescript
// call-screen.tsx에서 설정 반영
const { callSettings } = useCallSettings();

// 자막 영역
{callSettings.subtitleEnabled && subtitles.length > 0 && (
  <div className="subtitles-area">
    {subtitles.map(...)}
  </div>
)}
```

### 8.3 통화 후 자동 분석 설정 적용

```typescript
// use-voice-call.ts endCall()
function endCall() {
  // ... cleanup ...

  if (callSettings.autoAnalysis) {
    // 기존: sessionStorage에 저장 후 /chat/call/analyzing으로 이동
    navigateToAnalyzing();
  } else {
    // 분석 건너뛰기: 바로 회화탭으로 복귀
    router.push('/chat');
  }
}
```

### 8.4 연락처 → 통화 데이터 전달

```typescript
// /chat/call/contacts 에서 캐릭터 선택 시:
router.push(`/chat/call?characterId=${character.id}`);

// /chat/call에서 characterId로 캐릭터 정보 로드
// Phase 0: 하드코딩 (하루 기본값)
// Phase 3: DB에서 AiCharacter 조회
```

---

## 9. 환경 변수 추가

```env
# 통화 설정 기본값
CALL_DEFAULT_SILENCE_N5=3000
CALL_DEFAULT_SILENCE_N4=2500
CALL_DEFAULT_SILENCE_N3=2000
CALL_DEFAULT_SILENCE_N2=1500
CALL_DEFAULT_SILENCE_N1=1200
```

---

## 10. Gemini Live 확장 고려사항

### 음성 옵션

현재 `Kore` 한 가지만 사용 중. 캐릭터 확장 시 8개 음성으로 확대 예정:

| 캐릭터 | 음성 | 성별 | 공식 톤 |
|--------|------|------|---------|
| 🦊 하루 | `Kore` | 여성 | Firm (현재 사용 중) |
| 🐺 소라 | `Puck` | 남성 | Upbeat |
| 🐱 유키 | `Sulafat` | 여성 | Warm |
| 🐕 카이토 | `Charon` | 남성 | Informative |
| 🦋 미오 | `Leda` | 여성 | Youthful |
| 🐾 렌 | `Schedar` | 남성 | Even |
| 🌸 아오이 | `Gacrux` | 여성 | Mature |
| 🦅 리쿠 | `Orus` | 남성 | Firm |

> 상세 매칭 근거 및 대체 후보: [`CHARACTER_SYSTEM.md` §3](./CHARACTER_SYSTEM.md#3-gemini-음성-매칭)

### 모델 업그레이드

현재: `gemini-2.5-flash-native-audio-preview-12-2025` (프리뷰)
- 정식 버전 출시 시 모델 ID 업데이트 필요
- 프리뷰 → 정식 전환 시 설정 파라미터 변경 가능성

### 비용 관리

- Gemini Live API는 토큰 기반 과금
- 무료 유저: 하루 30분 제한 (PAYMENT_SYSTEM.md 참조)
- 통화 시간 추적: `DailyAiUsage.usedSeconds` 활용
