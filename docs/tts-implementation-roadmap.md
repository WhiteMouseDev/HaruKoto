# TTS 구현 로드맵

## 배경

일본어 학습 앱에서 단어 발음 재생은 핵심 기능. 백엔드 API(`POST /api/v1/vocab/tts`)는 구현되어 있으나,
모바일 앱에서 연동되지 않은 상태. 백엔드 코드에도 개선이 필요한 부분이 있음.

## Phase 1: 백엔드 수정 (API)

### 1-1. Gemini TTS 모델 업데이트
- `apps/api/app/services/ai.py`
- `gemini-2.5-flash-preview-tts` → `gemini-2.5-flash-tts` (GA 모델)

### 1-2. WAV → MP3 변환
- `apps/api/app/services/ai.py`
- PCM → WAV 대신 PCM → MP3로 변환 (pydub 또는 lameenc 사용)
- GCS 업로드 시 content_type `audio/wav` → `audio/mpeg`
- 파일 확장자 `.wav` → `.mp3`

### 1-3. make_public() 제거
- `apps/api/app/routers/tts.py`
- `blob.make_public()` 호출 제거
- 버킷 레벨 공개 설정에 의존 (Uniform bucket-level access)

### 1-4. GCS 경로 설계 문서와 일치
- `tts/{vocabId}.wav` → `tts/vocab/{vocabId}.mp3`

## Phase 2: 모바일 TTS 서비스

### 2-1. TTS API 연동
- `apps/mobile/lib/core/services/tts_service.dart` 신규
- API 호출 → audioUrl 반환 → audioplayers로 재생
- 인메모리 URL 캐시 (Map<String, String>)

### 2-2. Study Repository에 TTS 메서드 추가
- `apps/mobile/lib/features/study/data/study_repository.dart`
- `Future<String> fetchTtsUrl(String vocabId)` 추가

## Phase 3: 모바일 UI 연동

### 3-1. 퀴즈 화면 — 문제 단어 발음 버튼
- `four_choice_quiz.dart` — 문제 텍스트 옆 스피커 아이콘
- `matching_quiz.dart` — 왼쪽(일본어) 타일에 스피커 아이콘
- `cloze_quiz.dart`, `typing_quiz.dart` — 문제 영역에 스피커 아이콘

### 3-2. 퀴즈 결과 — 오답 단어 발음 버튼
- `wrong_answer_list.dart` — 각 오답 항목에 스피커 아이콘

### 3-3. 단어장 / 학습한 단어 — 발음 버튼
- `wordbook_page.dart` — 단어 카드에 스피커 아이콘
- `learned_words_content.dart` — 단어 항목에 스피커 아이콘

## 실행 전략

| 에이전트 | 담당 | Phase |
|---------|------|-------|
| agent-A | Phase 1 (백엔드 수정) | 1 |
| agent-B | Phase 2 + 3 (모바일 서비스 + UI) | 2→3 |

Phase 1과 Phase 2는 독립적이므로 병렬 실행 가능.
Phase 3는 Phase 2 완료 후 순차 진행.

## 검증

1. `cd apps/api && uv run ruff check app/ && uv run ruff format --check app/`
2. `cd apps/mobile && flutter analyze`
3. 시뮬레이터에서 퀴즈 → 스피커 아이콘 탭 → 발음 재생 확인
