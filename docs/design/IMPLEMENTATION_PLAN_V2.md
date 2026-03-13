# 화면 구조 v2 — 실행 계획

> **작성일**: 2026-03-13
> **기반 문서**: SCREEN_STRUCTURE_V2.md, API_GAP_ANALYSIS_V2.md
> **목적**: 스프린트 단위 작업 분류 + 팀 편성 + 실행 순서

---

## 전체 로드맵

```
Sprint 1 (즉시)     프론트만 변경 — API 불필요한 UI 개편
Sprint 2 (백엔드)   DB 모델 + 핵심 API (스테이지 시스템)
Sprint 3 (병렬)     학습 페이지 프론트 + 통계 API
Sprint 4 (마무리)   통계 프론트 + 마이페이지 + 도전과제
```

---

## Sprint 1: 프론트만 변경 (API 불필요)

> 백엔드 작업 없이 바로 착수 가능. 기존 API 그대로 사용.

### 작업 목록

| # | 작업 | 파일 | 난이도 |
|---|------|------|--------|
| 1-1 | 하단 탭 이름 변경: "회화" → "실전회화" | `main_shell.dart` (또는 bottom_nav) | 쉬움 |
| 1-2 | 퀴즈 중 탭바 숨김 (풀스크린) | `quiz_page.dart`, `app_router.dart` | 보통 |
| 1-3 | 퀴즈 종료 확인 다이얼로그 추가 | `quiz_page.dart` | 쉬움 |
| 1-4 | 마이페이지: 업적 섹션 제거 | `my_page.dart`, `achievements_section.dart` | 쉬움 |
| 1-5 | 마이페이지: 통화 설정 제거 | `app_settings_section.dart` | 쉬움 |
| 1-6 | 마이페이지: 하루 목표 설정 제거 | `settings_menu.dart` | 쉬움 |
| 1-7 | 실전회화 페이지: 통화 설정 추가 | `conversation_page.dart` 또는 채팅 메인 | 보통 |
| 1-8 | 학습 페이지: 탭 구조 변경 (추천/자율 → 단어\|문법\|문장배열\|가나) | `study_page.dart`, 관련 위젯 | 높음 |
| 1-9 | 학습 페이지: 동적 가나 탭 로직 | `study_page.dart` | 보통 |
| 1-10 | 학습 페이지: JLPT 레벨 탭 제거 + 상단 현재 레벨 표시 | `study_page.dart`, `free_tab.dart` | 보통 |
| 1-11 | 학습 페이지: 쓰기(타이핑) 모드 UI에서 제거 | `quiz_mode_selector.dart` | 쉬움 |
| 1-12 | 홈: 바로가기 4개 추가 (단어장, 오답노트, 도전과제, 가나차트) | `home_page.dart` | 보통 |
| 1-13 | 홈: 스트릭 섹션 컴팩트화 + 탭→달력 바텀시트 | `home_page.dart`, 신규 위젯 | 보통 |

### 팀 편성

```
[Agent A — 학습 페이지 UI 개편] (1-8, 1-9, 1-10, 1-11)
  핵심 작업. 탭 구조 전면 변경 + 동적 가나 탭.
  기존 추천/자율 탭, N1~N5 레벨 탭, 카테고리 셀렉터 제거.
  단어|문법|문장배열|가나 단일 탭으로 교체.
  현재 단계에서는 스테이지 리스트 대신 기존 퀴즈 시작 UI를 탭별로 배치.

[Agent B — 홈 + 마이페이지 + 기타 UI] (1-1~1-7, 1-12, 1-13)
  비교적 단순한 UI 변경 묶음.
  탭 이름, 마이페이지 섹션 정리, 홈 바로가기, 스트릭 컴팩트화.
  퀴즈 풀스크린 + 종료 다이얼로그.
```

### 완료 기준
- `flutter analyze` 에러 0
- 시뮬레이터에서 전체 탭 탐색 가능
- 학습 페이지: 단어|문법|문장배열|가나 탭 동작 확인
- 마이페이지: 업적/통화설정/하루목표 제거 확인
- 퀴즈: 풀스크린 + 종료 다이얼로그 확인

---

## Sprint 2: DB 모델 + 핵심 API (스테이지 시스템)

> Sprint 1과 병렬 가능 (백엔드 독립 작업). 학습 페이지 v2의 핵심 블로커.

### 작업 목록

| # | 작업 | 위치 | 난이도 |
|---|------|------|--------|
| 2-1 | `study_stages` DB 모델 생성 | `apps/api/app/models/` | 보통 |
| 2-2 | `user_study_stage_progress` DB 모델 생성 | `apps/api/app/models/` | 보통 |
| 2-3 | DB 마이그레이션 실행 | Alembic | 쉬움 |
| 2-4 | 스테이지 시드 데이터 생성 (N5 단어/문법/문장) | 시드 스크립트 | 보통 |
| 2-5 | `GET /study/stages` API 구현 | `apps/api/app/routers/study.py` | 보통 |
| 2-6 | `POST /quiz/start` 수정 — `stageId` + `matching` 모드 | `apps/api/app/routers/quiz.py` | 높음 |
| 2-7 | `POST /quiz/complete` 수정 — 스테이지 진도 업데이트 | `apps/api/app/routers/quiz.py` | 보통 |
| 2-8 | `User` 모델에 `app_settings` JSON 컬럼 추가 | `apps/api/app/models/user.py` | 쉬움 |
| 2-9 | `PATCH /user/profile` — `app_settings` 지원 | `apps/api/app/routers/user.py` | 쉬움 |
| 2-10 | `POST /auth/onboarding` — `show_kana` 파라미터 추가 | `apps/api/app/routers/auth.py` | 쉬움 |
| 2-11 | `GET /quiz/recommendations` — 카테고리별 분리 | `apps/api/app/routers/quiz.py` | 보통 |
| 2-12 | `DailyProgress` 테이블 확장 (`grammar_studied`, `sentences_studied`) | DB 마이그레이션 | 쉬움 |
| 2-13 | 학습 시간 추적 로직 (`quiz/complete`, `chat/end`에서 누적) | 서비스 로직 | 보통 |

### 팀 편성

```
[Agent C — 스테이지 시스템] (2-1~2-7)
  가장 큰 작업. DB 모델 → 시드 → API → 퀴즈 연동까지.
  가나 스테이지(KanaLearningStage) 패턴 참고하여 범용 설계.

[Agent D — 유저/통계 DB + API 수정] (2-8~2-13)
  비교적 단순한 수정. User 모델 확장, DailyProgress 확장,
  기존 API 파라미터 추가.
```

### 완료 기준
- 마이그레이션 성공
- `GET /study/stages?category=vocabulary&level=N5` → 스테이지 리스트 반환
- `POST /quiz/start` with `stageId` → 해당 스테이지 문제만 출제
- `POST /quiz/start` with `mode=matching` → 매칭 문제 반환
- 기존 테스트 통과 + 신규 엔드포인트 테스트

---

## Sprint 3: 학습 페이지 프론트 완성 + 통계 API

> Sprint 2 완료 후. 스테이지 API를 사용하여 프론트엔드 완성 + 통계 API 병렬 개발.

### 작업 목록

| # | 작업 | 위치 | 난이도 |
|---|------|------|--------|
| 3-1 | 학습 페이지: 스테이지 리스트 UI (모드별 진도 표시) | Flutter 위젯 | 높음 |
| 3-2 | 학습 페이지: 모드 선택 + 하루 목표 바텀시트 | Flutter 위젯 | 보통 |
| 3-3 | 학습 페이지: 스테이지 기반 퀴즈 시작 연동 | 프로바이더 + 라우팅 | 보통 |
| 3-4 | 홈: 오늘의 학습 카드 (카테고리별 탭 + 추천 데이터) | `home_page.dart` | 보통 |
| 3-5 | 매칭 퀴즈 위젯 — API 연동 수정 (현재 로컬 데이터 사용) | `matching_quiz.dart` | 보통 |
| 3-6 | `GET /stats/heatmap` API 구현 | `apps/api/app/routers/stats.py` | 보통 |
| 3-7 | `GET /stats/jlpt-progress` API 구현 | `apps/api/app/routers/stats.py` | 보통 |
| 3-8 | `GET /stats/time-chart` API 구현 | `apps/api/app/routers/stats.py` | 보통 |
| 3-9 | `GET /stats/volume-chart` API 구현 | `apps/api/app/routers/stats.py` | 보통 |
| 3-10 | `GET /stats/by-category` API 구현 | `apps/api/app/routers/stats.py` | 보통 |
| 3-11 | `GET /achievements` API 구현 | `apps/api/app/routers/` 신규 | 쉬움 |
| 3-12 | `PATCH /study/daily-goal` API 구현 | `apps/api/app/routers/study.py` | 쉬움 |

### 팀 편성

```
[Agent E — 학습 페이지 프론트 완성] (3-1~3-5)
  Sprint 2의 스테이지 API를 사용하여 프론트 완성.
  스테이지 리스트 → 모드 선택 바텀시트 → 퀴즈 시작 전체 플로우.

[Agent F — 통계 + 도전과제 API] (3-6~3-12)
  통계 관련 신규 API 5개 + 도전과제 API + 하루 목표 API.
  DailyProgress, QuizSession 데이터 기반 집계 쿼리.
```

### 완료 기준
- 학습 페이지: 스테이지 선택 → 모드 선택 → 퀴즈 시작 → 결과 전체 플로우
- 통계 API: 모든 엔드포인트에서 유효한 데이터 반환
- 매칭 퀴즈: API 연동 완료

---

## Sprint 4: 통계 프론트 + 마무리

> Sprint 3 완료 후. 통계 API를 사용하여 프론트 완성 + 전체 QA.

### 작업 목록

| # | 작업 | 위치 | 난이도 |
|---|------|------|--------|
| 4-1 | 학습통계: 기간별 탭 (히트맵 + 학습시간 차트 + 학습량 차트) | Flutter 위젯 | 높음 |
| 4-2 | 학습통계: 학습별 탭 (카테고리 서브탭 + 7일 바차트) | Flutter 위젯 | 보통 |
| 4-3 | 학습통계: JLPT 진도 탭 (레벨별 달성률 + breakdown) | Flutter 위젯 | 보통 |
| 4-4 | 도전과제 전용 화면 (홈 바로가기 → 전체 업적 그리드) | Flutter 위젯 | 보통 |
| 4-5 | 마이페이지: 앱 설정 서버 동기화 (app_settings API 연동) | 프로바이더 | 쉬움 |
| 4-6 | 실전회화: 난이도 JLPT 연동 + 시나리오 카테고리 필터 | Flutter 위젯 | 보통 |
| 4-7 | 전체 QA + 버그 수정 | 전체 | — |

### 팀 편성

```
[Agent G — 통계 프론트] (4-1~4-3)
  차트 라이브러리 활용 (fl_chart 등).
  히트맵, 라인차트, 바차트, 프로그레스 바.

[Agent H — 나머지 + QA] (4-4~4-7)
  도전과제 화면, 마이페이지 동기화, 실전회화 개선.
  전체 플로우 QA.
```

### 완료 기준
- 모든 탭에서 데이터 정상 표시
- SCREEN_STRUCTURE_V2.md의 모든 화면 구현 완료
- `flutter analyze` 에러 0
- 시뮬레이터에서 전체 플로우 테스트 통과

---

## 의존성 요약

```
Sprint 1 ──────────────────────────→ (프론트 UI 개편, API 불필요)
    ↓ (병렬)
Sprint 2 ──────────────────────────→ (DB + 핵심 API)
    ↓ (Sprint 2 완료 필요)
Sprint 3 ──────────────────────────→ (학습 프론트 + 통계 API)
    ↓ (Sprint 3 완료 필요)
Sprint 4 ──────────────────────────→ (통계 프론트 + QA)
```

- Sprint 1과 2는 **병렬 진행 가능**
- Sprint 3은 Sprint 2(스테이지 API) 완료 후 착수
- Sprint 4는 Sprint 3(통계 API) 완료 후 착수

---

## 실행 시 주의사항

### Claude Code 세션 관리
- 각 Sprint 시작 시 이 문서 + 관련 문서(SCREEN_STRUCTURE_V2.md, API_GAP_ANALYSIS_V2.md)를 먼저 읽도록 지시
- Agent는 작업 완료 시 변경 파일 목록 + 테스트 결과를 보고
- Sprint 간 커밋을 반드시 남겨서 롤백 가능하게

### API 변경 시 프론트 동기화
- 백엔드 API 응답 형식이 변경되면 `docs/design/API_GAP_ANALYSIS_V2.md`의 해당 섹션 업데이트
- 프론트 Agent에게 변경된 API 스펙을 명시적으로 전달

### 점진적 배포
- Sprint 1 완료 시점에 한 번 배포 (UI만 변경, 기능 동일)
- Sprint 2+3 완료 시점에 배포 (학습 페이지 v2)
- Sprint 4 완료 시점에 배포 (통계 v2 + 전체 완성)
