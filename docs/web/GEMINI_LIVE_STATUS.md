# Gemini Live API — 구현 현황 및 활용 가이드

> 최종 업데이트: 2026-03-04
> 모델: `gemini-2.5-flash-native-audio-preview-12-2025`
> SDK: `@google/genai`
> 공식 문서: https://ai.google.dev/gemini-api/docs/live

---

## 구현 현황

### 사용 중 (✅)

| 기능 | 설정값 | 파일 |
|------|--------|------|
| **responseModalities** | `[Modality.AUDIO]` | `use-gemini-live.ts:94` |
| **voiceName** | 캐릭터별 지정 (기본: `Kore`) | `use-gemini-live.ts:97` |
| **systemInstruction** | 캐릭터별 프롬프트 | `use-gemini-live.ts:100` |
| **enableAffectiveDialog** | `true` | `use-gemini-live.ts:101` |
| **proactiveAudio** | `true` | `use-gemini-live.ts:102` |
| **inputAudioTranscription** | 활성 | `use-gemini-live.ts:103` |
| **outputAudioTranscription** | 활성 | `use-gemini-live.ts:104` |
| **startOfSpeechSensitivity** | `HIGH` | `use-gemini-live.ts:108` |
| **endOfSpeechSensitivity** | `HIGH` | `use-gemini-live.ts:109` |
| **prefixPaddingMs** | `300` | `use-gemini-live.ts:110` |
| **silenceDurationMs** | 사용자 설정 (기본: 캐릭터별) | `use-gemini-live.ts:111` |
| **sessionResumption** | 핸들 기반 재연결 | `use-gemini-live.ts:115-117` |
| **goAway 핸들링** | 선제적 재연결 | `use-gemini-live.ts:135-141` |
| **Ephemeral Token** | 서버에서 발급 → 클라이언트 사용 | `use-gemini-live.ts:81-83` |
| **재연결** | 지수 백오프, 최대 3회 | `use-gemini-live.ts:262-299` |

### 미사용 — 구현하면 좋은 것 (🔵)

| 기능 | 설명 | 기대 효과 | 난이도 |
|------|------|-----------|--------|
| **contextWindowCompression** | `slidingWindow` + `triggerTokens`로 오래된 맥락 자동 압축 | 현재 ~10분 제한 → 무제한 통화 가능 | 낮음 (설정 추가만) |
| **thinkingConfig** | `thinkingBudget`으로 추론 활성화 | 복잡한 문법 설명 시 정확도 향상 | 낮음 |
| **activityHandling** | `NO_INTERRUPTION` 모드 | AI가 긴 설명 중 사용자 소리에 끊기지 않는 옵션 | 낮음 |
| **turnCoverage** | `TURN_INCLUDES_ALL_INPUT` | 배경 소음 포함 전체 오디오 전달, 환경음 인식 | 낮음 |
| **Google Search** | `tools: [{ google_search: {} }]` | "이 단어 뜻이 뭐야?" → 실시간 검색 연동 | 중간 |
| **Function Calling** | 단어장 저장, 퀴즈 시작 등 앱 기능 연동 | "이 단어 단어장에 넣어줘" 음성 명령 | 중간 |
| **aiResponseSpeed** | Gemini API에 직접 대응 파라미터 없음 | TTS 재생 속도 조절로 클라이언트에서 구현 가능 | 중간 |

### 미사용 — 구현 불필요 (⬜)

| 기능 | 미사용 이유 |
|------|-------------|
| **Manual VAD** (`disabled: true`) | Auto VAD로 충분. 수동 제어 불필요 |
| **mediaResolution** | 비디오 입력 미사용 |
| **temperature / topP / topK** | 회화용 기본값 적절 |
| **candidateCount** | 실시간 오디오에서 복수 후보 불필요 |
| **presencePenalty / frequencyPenalty** | 자연 회화에서 기본값 적절 |
| **maxOutputTokens** | 음성 대화는 짧은 턴이라 제한 불필요 |
| **Vertex AI RAG** | Vertex AI 미사용 (Google AI Studio 사용 중) |
| **Code Execution** | Live API 미지원 |

---

## 사용 가능한 음성 (30개)

| 음성 | 특징 | 음성 | 특징 |
|------|------|------|------|
| **Kore** | Firm (현재 기본) | Puck | Upbeat |
| Zephyr | Bright | Fenrir | Excitable |
| Orus | Firm | Aoede | Breezy |
| Autonoe | Bright | Enceladus | Breathy |
| Umbriel | Easy-going | Algieba | Smooth |
| Erinome | Clear | Algenib | Gravelly |
| Laomedeia | Upbeat | Achernar | Soft |
| Schedar | Even | Gacrux | Mature |
| Achird | Friendly | Zubenelgenubi | Casual |
| Sadachbia | Lively | Sadaltager | Knowledgeable |
| Charon | Informative | Leda | Youthful |
| Callirrhoe | Easy-going | Iapetus | Clear |
| Despina | Smooth | Rasalgethi | Informative |
| Alnilam | Firm | Pulcherrima | Forward |
| Vindemiatrix | Gentle | Sulafat | Warm |

---

## 지원 언어 (25개)

일본어(`ja-JP`)와 한국어(`ko-KR`) 모두 지원. 시스템 인스트럭션으로 언어 유도 가능.
Native audio 모델은 대화 중 자동 언어 전환 지원.

---

## 세션 제한

| 항목 | 값 |
|------|-----|
| WebSocket 수명 | ~10분 (세션 재개로 연장) |
| 오디오 전용 (압축 없음) | 15분 |
| 컨텍스트 압축 사용 시 | 무제한 |
| 재개 토큰 유효 시간 | 2시간 |
| 입력 토큰 한도 | 128K |
| 출력 토큰 한도 | 8,192 (Google AI) |

---

## 권장 개선 우선순위

### 1순위: `contextWindowCompression` 추가
현재 세션 재개로 ~10분 연장은 되지만, 컨텍스트 압축 없이는 오래된 대화 맥락이 유실됨.
설정 한 줄 추가로 무제한 통화 + 맥락 유지 가능.

```typescript
contextWindowCompression: {
  slidingWindow: { targetTokens: 50000 },
  triggerTokens: 100000,
},
```

### 2순위: Function Calling (단어장 저장)
"이 단어 단어장에 넣어줘" → 앱 내 단어장 API 자동 호출. 학습 앱의 핵심 차별화.

### 3순위: `thinkingConfig` 활성화
N3 이상 레벨에서 문법 설명 정확도 향상.

---

## 오디오 스펙

| 항목 | 입력 | 출력 |
|------|------|------|
| 포맷 | Raw 16-bit PCM, mono, LE | Raw 16-bit PCM, LE |
| 샘플레이트 | 16kHz | 24kHz |
| MIME | `audio/pcm;rate=16000` | - |
