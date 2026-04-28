# 음성 통화 시스템 기술 분석

> Gemini Live API 기반 실시간 음성 통화 아키텍처 분석 및 모바일 안정성 개선 방안

---

## 1. 현재 아키텍처 개요

```
┌─────────────────────────────────────────────────────────────────────┐
│ Client (Browser / Mobile WebView)                                   │
│                                                                     │
│  ┌──────────────┐   PCM 16kHz   ┌───────────────┐   base64 JSON    │
│  │ Mic (48kHz)  ├──────────────►│ AudioWorklet  ├─────────────┐    │
│  │ getUserMedia │  resampling   │ pcm-processor │             │    │
│  └──────────────┘               └───────────────┘             │    │
│                                                                │    │
│  ┌──────────────┐   PCM 24kHz   ┌───────────────┐   WebSocket │    │
│  │ Speaker      │◄──────────────┤ PCM Player    │◄────────────┤    │
│  │ AudioContext │  gapless      │ BufferSource  │             │    │
│  └──────────────┘  scheduling   └───────────────┘             │    │
│                                                                │    │
│  ┌─────────────────────────────────────────────────────────────┤    │
│  │                    use-gemini-live.ts                        │    │
│  │  ┌─────────┐   sendRealtimeInput()   ┌──────────────────┐  │    │
│  │  │ Session ├────────────────────────►│                  │  │    │
│  │  │  (SDK)  │◄────────────────────────┤  Gemini Live API │  │    │
│  │  └─────────┘   serverContent         │  (WebSocket)     │  │    │
│  └─────────────────────────────────────┬└──────────────────┘  │    │
│                                        │                       │    │
└────────────────────────────────────────┼───────────────────────┘    │
                                         │                            │
┌────────────────────────────────────────┼────────────────────────────┘
│ Next.js Server                         │
│                                        │
│  POST /api/v1/chat/live-token          │
│  ┌─────────────────────────┐           │
│  │ ephemeral token (5분)   ├───────────┘
│  │ authTokens.create()     │
│  └─────────────────────────┘
│
│  POST /api/v1/chat/live-feedback
│  ┌─────────────────────────┐
│  │ transcript → AI 분석    │
│  │ → DB 저장 + 게이미피케이션│
│  └─────────────────────────┘
└─────────────────────────────────────────────────────────────────────
```

### 핵심 설정값

| 설정 | 값 | 파일 |
|------|-----|------|
| 모델 | `gemini-2.5-flash-native-audio-preview-12-2025` | `use-gemini-live.ts:34` |
| 음성 | `Kore` | `use-gemini-live.ts:35` |
| API 버전 | `v1alpha` | `live-token/route.ts` |
| 응답 모달리티 | `AUDIO` only | `use-gemini-live.ts:77` |
| 입력 샘플레이트 | 16,000 Hz (16kHz PCM Int16) | `pcm-processor.js:9` |
| 출력 샘플레이트 | 24,000 Hz (24kHz PCM Int16) | `use-pcm-player.ts:31` |
| 녹음 샘플레이트 | 48,000 Hz (브라우저 네이티브) | `use-pcm-recorder.ts:44` |
| 청크 크기 | ~100ms (1,600 samples) | `pcm-processor.js:38` |
| 토큰 만료 | 5분 (300,000ms) | `live-token/route.ts:38` |
| 토큰 레이트 리밋 | 5회/분 | `rate-limit.ts:92` |
| VAD 설정 | **미설정 (Gemini 기본값)** | - |

---

## 2. 상태 머신 & 통화 흐름

### 메인 상태 (LiveCallState)

```
idle ──► connecting ──► connected ──► ending ──► ended
              │                           ▲
              └──► error (→ idle)          │
                                          │
              onDisconnected (unexpected) ─┘
```

### 서브 상태 (connected 상태 내)

```
idle ◄──► ai_speaking ◄──► user_speaking
  │            │                 │
  │   onAudioChunk 수신    barge-in (interrupted)
  │   → ai_speaking        → user_speaking
  │                                │
  │   turnComplete              inputTranscription
  │   → idle                    → (Gemini VAD 처리)
  └────────────────────────────────┘
```

### 통화 시작 시퀀스

```
1. user clicks "call" button
2. setState('connecting')
3. player.init()                    ← AudioContext 초기화 (유저 제스처 필수)
4. playRingtone()                   ← 연결 대기 중 벨소리
5. await gemini.connect()
   ├─ POST /api/v1/chat/live-token  ← 서버에서 임시 토큰 발급
   ├─ new GoogleGenAI({ apiKey: token })
   ├─ client.live.connect({ model, config, callbacks })
   │   ├─ onopen: (비어있음)
   │   ├─ onmessage: 오디오/텍스트/턴 처리
   │   ├─ onerror: 에러 상태 전환
   │   └─ onclose: 연결 해제 감지
   └─ sendClientContent("会話を始めてください")  ← AI 인사 트리거
6. stopRingtone()
7. await recorder.start()
   ├─ getUserMedia({ echoCancellation, noiseSuppression, autoGainControl })
   ├─ AudioContext(48kHz) → AudioWorklet('pcm-processor')
   └─ worklet.port.onmessage → base64 → gemini.sendAudio()
8. setState('connected')
9. startTimer()
```

### 메시지 수신 처리 흐름

```
Gemini WebSocket message 수신
│
├─ serverContent.modelTurn.parts[].inlineData
│   └─ onAudioChunk(base64) → player.enqueue() → 스피커 출력
│
├─ serverContent.outputTranscription.text
│   └─ onAiTextDelta(text) → currentAiText 업데이트 (실시간 자막)
│
├─ serverContent.inputTranscription.text
│   └─ transcriptRef에 유저 발화 누적 → onTranscript() (기록용)
│
├─ serverContent.turnComplete
│   └─ AI 발화 완료 → transcript 저장 → subtitles에 추가 → currentAiText 초기화
│
└─ serverContent.interrupted (barge-in)
    └─ player.interrupt() → 현재 AI 오디오 즉시 중단 → subState='user_speaking'
```

---

## 3. 오디오 파이프라인 상세

### 녹음 (입력)

```
Mic (48kHz Float32)
  │
  ├─ echoCancellation: true
  ├─ noiseSuppression: true
  └─ autoGainControl: true
  │
  ▼
MediaStreamSource → AnalyserNode (FFT 256, 파형 시각화용)
  │
  ▼
AudioWorkletNode ('pcm-processor')
  │  ┌─────────────────────────────────────────────┐
  │  │ 리샘플링: 48kHz → 16kHz (선형 보간법)         │
  │  │ 변환: Float32 → Int16 PCM                    │
  │  │ 버퍼링: 1,600 samples (~100ms) 단위로 전송    │
  │  └─────────────────────────────────────────────┘
  │
  ▼
base64 인코딩 → gemini.sendRealtimeInput()
```

### 재생 (출력)

```
Gemini serverContent.modelTurn.parts[].inlineData.data (base64)
  │
  ▼
atob() → Uint8Array → Int16Array → Float32Array
  │
  ▼
AudioContext(24kHz).createBuffer() → AudioBufferSourceNode
  │
  ├─ connect(AnalyserNode) → 파형 시각화
  ├─ gapless scheduling: Math.max(now, nextStartTime)
  └─ source.start(startAt)
  │
  ▼
Speaker output
```

### 브라우저 오디오 제약 (모바일 영향)

| 제약 | 역할 | 모바일 문제점 |
|------|------|-------------|
| `echoCancellation` | AI 음성이 마이크로 돌아오는 것 방지 | 고지연 네트워크에서 수렴 실패 → 에코/버즈 발생 |
| `noiseSuppression` | 배경 소음 제거 | SNR 낮을 때 사용자 음성까지 억제할 수 있음 |
| `autoGainControl` | 소리 크기 자동 조절 | 배경 소음이 클 때 더 증폭 → Gemini VAD 혼동 |

---

## 4. 모바일 환경 문제점 분석

### 4.1 "AI가 대답을 안 하는" 현상의 가능한 원인

#### 원인 A: 배경 소음으로 Gemini VAD 혼동 (가능성: 높음)

```
모바일 환경 소음 → autoGainControl 증폭
→ Gemini가 "유저가 계속 말하고 있다"로 인식
→ turnComplete가 절대 발생하지 않음
→ AI가 응답할 타이밍을 잡지 못함
```

현재 Gemini VAD 설정이 **기본값**으로 되어 있어, 모바일 환경의 지속적인 배경 소음을
발화로 오인할 가능성이 높음.

**근거**: `use-gemini-live.ts`에서 `realtimeInputConfig.automaticActivityDetection`이
설정되지 않음. SDK 타입(`gemini-live.ts:20-26`)에는 감도 조절 옵션이 존재.

#### 원인 B: 네트워크 불안정으로 WebSocket 연결 끊김 (가능성: 높음)

```
WiFi → LTE 전환 / 일시적 연결 끊김
→ WebSocket onclose 발생
→ aliveRef = false
→ sendAudio() 무시 (조용히 실패)
→ 유저는 통화 중인 줄 알지만 실제로는 연결 끊김
```

`sendAudio`에서 에러 발생 시 `aliveRef.current = false`로 설정 후 **조용히 중단**.
유저에게 어떤 피드백도 없음.

#### 원인 C: 오디오 청크 손실 (가능성: 중간)

```
네트워크 지연 → WebSocket 전송 버퍼 가득 참
→ sendRealtimeInput() 예외 발생
→ catch { aliveRef.current = false }
→ 이후 모든 오디오 전송 중단 (복구 없음)
```

#### 원인 D: AudioContext 일시 정지 (가능성: 중간, iOS 특히)

```
iOS: 화면 잠금 / 다른 앱 전환 / 알림 표시
→ AudioContext.state === 'interrupted' (iOS) 또는 'suspended'
→ 녹음/재생 모두 중단
→ 복귀 시 resume() 호출 없음 (녹음 측은 resume 로직 없음)
```

#### 원인 E: 토큰 만료 (가능성: 낮음, 5분 이상 통화 시)

```
통화 5분 경과 → ephemeral token 만료
→ Gemini 서버가 WebSocket 닫음
→ onclose → endCall()
```

---

### 4.2 현재 에러 처리 현황

| 상황 | 현재 처리 | 문제점 |
|------|----------|--------|
| WebSocket 연결 끊김 | `onclose` → toast + endCall | 재연결 시도 없음 |
| `sendAudio` 예외 | `aliveRef = false` (조용히) | 유저 인지 불가, 복구 없음 |
| `gemini.connect()` 행 | 무한 대기 | 타임아웃 없음, "연결 중" 무한 |
| 토큰 만료 | WebSocket close | 갱신 메커니즘 없음 |
| 마이크 권한 거부 | catch → error 표시 | 정상 처리됨 |
| `onerror` 이벤트 | state='error' + toast | 재시도 없음 |
| AudioContext 일시 정지 | Player만 resume, Recorder 미처리 | 녹음 중단 인지 불가 |
| 네트워크 오프라인 | 감지 안 함 | `navigator.onLine` 미사용 |

---

## 5. 개선 방안

### 5.1 Gemini VAD 감도 설정 (우선순위: 최고)

Live API 기본값과 맞춰 `HIGH`를 명시한다. 짧거나 작은 발화를 놓치지 않는
방향을 우선하되, 소음 환경의 오탐 증가는 기기 테스트로 확인한다.

```typescript
// use-gemini-live.ts — config에 추가
config: {
  responseModalities: [Modality.AUDIO],
  speechConfig: { /* ... */ },
  systemInstruction: SYSTEM_INSTRUCTION,
  inputAudioTranscription: {},
  outputAudioTranscription: {},
  // 추가
  realtimeInputConfig: {
    automaticActivityDetection: {
      startOfSpeechSensitivity: 'START_SENSITIVITY_HIGH',
      endOfSpeechSensitivity: 'END_SENSITIVITY_HIGH',
    },
  },
},
```

- `START_SENSITIVITY_HIGH`: 발화 시작을 더 자주 감지해 짧거나 약한 발화 누락을 줄임
- `END_SENSITIVITY_HIGH`: 발화 종료를 더 자주 감지해 응답 시작 지연을 줄임
- 모바일 소음 환경에서 오탐이 늘어나면 `LOW` 전환을 별도 튜닝으로 검토

### 5.2 WebSocket 재연결 로직 (우선순위: 높음)

```typescript
// 지수 백오프 재연결 (최대 3회)
async function reconnect(attempt = 0): Promise<boolean> {
  if (attempt >= 3) return false;
  const delay = Math.pow(2, attempt) * 1000; // 1s, 2s, 4s
  await sleep(delay);
  try {
    await connect();
    return true;
  } catch {
    return reconnect(attempt + 1);
  }
}
```

`onclose`에서 예상치 못한 종료 시 자동 재연결 시도,
실패 시 유저에게 "재연결 실패" 알림.

### 5.3 네트워크 상태 모니터링 (우선순위: 높음)

```typescript
// 네트워크 상태 감지
useEffect(() => {
  const handleOffline = () => {
    toast.warning('네트워크 연결이 끊겼습니다.');
    // 재연결 대기 모드
  };
  const handleOnline = () => {
    toast.info('네트워크가 복구되었습니다. 재연결 중...');
    reconnect();
  };
  window.addEventListener('offline', handleOffline);
  window.addEventListener('online', handleOnline);
  return () => {
    window.removeEventListener('offline', handleOffline);
    window.removeEventListener('online', handleOnline);
  };
}, []);
```

### 5.4 연결 타임아웃 (우선순위: 중간)

```typescript
// gemini.connect()에 10초 타임아웃
const connectWithTimeout = (ms: number) =>
  Promise.race([
    gemini.connect(),
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error('연결 시간 초과')), ms)
    ),
  ]);

await connectWithTimeout(10_000);
```

### 5.5 오디오 전송 실패 감지 & 피드백 (우선순위: 중간)

```typescript
// sendAudio 실패 시 유저에게 알림
const sendAudio = useCallback((base64: string) => {
  if (!session || !aliveRef.current) return;
  try {
    session.sendRealtimeInput({ media: { /* ... */ } });
    failCountRef.current = 0;
  } catch {
    failCountRef.current++;
    if (failCountRef.current >= 3) {
      aliveRef.current = false;
      optionsRef.current.onError('음성 전송에 실패했습니다.');
    }
  }
}, []);
```

### 5.6 토큰 갱신 (우선순위: 중간)

```typescript
// 4분 경과 시 새 토큰 준비 → 재연결
useEffect(() => {
  if (state !== 'connected') return;
  const timer = setTimeout(() => {
    // 새 토큰 발급 후 재연결 or 경고
    toast.info('통화 시간이 곧 만료됩니다.');
  }, 4 * 60 * 1000); // 4분
  return () => clearTimeout(timer);
}, [state]);
```

### 5.7 AudioContext 상태 감시 (우선순위: 낮음)

```typescript
// Recorder AudioContext 일시 정지 감지
useEffect(() => {
  const ctx = audioContextRef.current;
  if (!ctx) return;
  const handleStateChange = () => {
    if (ctx.state === 'suspended' || ctx.state === 'interrupted') {
      ctx.resume().catch(() => {});
    }
  };
  ctx.addEventListener('statechange', handleStateChange);
  return () => ctx.removeEventListener('statechange', handleStateChange);
}, []);
```

---

## 6. 개선 우선순위 정리

| 순위 | 항목 | 효과 | 난이도 |
|------|------|------|--------|
| 1 | Gemini VAD 감도 설정 | 배경 소음 문제 직접 해결 | 낮음 (설정값 추가) |
| 2 | WebSocket 재연결 로직 | 네트워크 끊김 자동 복구 | 중간 |
| 3 | 네트워크 상태 모니터링 | 오프라인 감지 + UX 개선 | 낮음 |
| 4 | 연결 타임아웃 | "연결 중" 무한 대기 방지 | 낮음 |
| 5 | 오디오 전송 실패 감지 | 조용한 실패 → 명시적 알림 | 낮음 |
| 6 | 토큰 갱신 | 5분+ 통화 지원 | 중간 |
| 7 | AudioContext 상태 감시 | iOS 백그라운드 전환 대응 | 낮음 |

---

## 7. 참고: 파일 목록

| 파일 | 역할 |
|------|------|
| `hooks/use-gemini-live.ts` | WebSocket 연결, 메시지 송수신, 에러 처리 |
| `hooks/use-pcm-recorder.ts` | 마이크 녹음, AudioWorklet, PCM 인코딩 |
| `hooks/use-pcm-player.ts` | PCM 디코딩, gapless 재생, barge-in |
| `hooks/use-voice-call.ts` | 통화 상태 관리, 위 3개 훅 조합 |
| `public/pcm-processor.js` | AudioWorklet (48kHz→16kHz 리샘플링) |
| `api/v1/chat/live-token/route.ts` | 임시 토큰 발급 (5분 만료) |
| `api/v1/chat/live-feedback/route.ts` | 통화 종료 후 AI 피드백 생성 |
| `components/features/chat/call-screen.tsx` | 통화 UI (자막, 버튼, 파형) |
| `components/features/chat/call-waveform.tsx` | 아바타 + 음파 링 애니메이션 |
| `types/gemini-live.ts` | WebSocket 프로토콜 타입 정의 |
