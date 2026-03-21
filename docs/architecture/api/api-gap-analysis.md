# API 갭 분석 — 화면 구조 v2

> 작성일: 2026-03-13
> 목적: 새 화면 구조(SCREEN_STRUCTURE_V2.md) 구현에 필요한 API 변경사항 분석

---

## 1. 현재 API 엔드포인트 목록

### Auth (`/api/v1/auth`)
| Method | Path | 설명 |
|--------|------|------|
| POST | `/auth/ensure-user` | Supabase JWT 검증 + DB 유저 자동 생성 |
| POST | `/auth/onboarding` | 온보딩 완료 (닉네임, JLPT 레벨, 일일 목표, 학습 목표) |

### User (`/api/v1/user`)
| Method | Path | 설명 |
|--------|------|------|
| GET | `/user/profile` | 프로필 + 요약 통계 + 업적 목록 |
| PATCH | `/user/profile` | 프로필 수정 (닉네임, JLPT 레벨, call_settings 등) |
| POST | `/user/avatar` | 아바타 이미지 업로드 (GCS) |
| PATCH | `/user/avatar` | 아바타 URL 직접 수정 |
| DELETE | `/user/account` | 계정 삭제 (GCS + DB + Supabase Auth) |
| PATCH | `/user/account` | 계정 정보 수정 (닉네임, 이메일) |

### Stats (`/api/v1/stats`)
| Method | Path | 설명 |
|--------|------|------|
| GET | `/stats/dashboard` | 대시보드 (오늘 통계, 스트릭, 주간, 레벨 진도, 가나 진도) |
| GET | `/stats/history?year=&month=` | 월별 학습 기록 (DailyProgress) |

### Quiz (`/api/v1/quiz`)
| Method | Path | 설명 |
|--------|------|------|
| POST | `/quiz/start` | 퀴즈 시작 (mode: normal/cloze/arrange/review) |
| POST | `/quiz/answer` | 문제 답변 + SRS 업데이트 |
| POST | `/quiz/complete` | 퀴즈 완료 + XP/스트릭/업적 처리 |
| GET | `/quiz/incomplete` | 미완료 퀴즈 세션 조회 |
| POST | `/quiz/resume` | 미완료 퀴즈 이어하기 |
| GET | `/quiz/stats?level=&type=` | 퀴즈 통계 (전체 or 레벨+타입별) |
| GET | `/quiz/wrong-answers?sessionId=` | 세션별 오답 목록 |
| GET | `/quiz/recommendations` | 추천 학습 (복습 예정, 신규, 오답 카운트) |

### Study (`/api/v1/study`)
| Method | Path | 설명 |
|--------|------|------|
| GET | `/study/learned-words` | 학습한 단어 목록 (페이지네이션, 검색, 필터) |
| GET | `/study/wrong-answers` | 오답노트 (페이지네이션, 정렬) |

### Wordbook (`/api/v1/wordbook`)
| Method | Path | 설명 |
|--------|------|------|
| GET | `/wordbook/` | 단어장 목록 |
| POST | `/wordbook/` | 단어장 추가 |
| GET | `/wordbook/{id}` | 단어장 항목 상세 |
| PATCH | `/wordbook/{id}` | 단어장 항목 수정 |
| DELETE | `/wordbook/{id}` | 단어장 항목 삭제 |

### Kana (`/api/v1/kana`)
| Method | Path | 설명 |
|--------|------|------|
| GET | `/kana/characters` | 가나 문자 목록 |
| GET | `/kana/stages` | 가나 스테이지 목록 + 유저 진도 |
| GET | `/kana/progress` | 가나 진도 요약 (히라가나/가타카나) |
| POST | `/kana/progress` | 가나 학습 기록 |
| POST | `/kana/quiz/start` | 가나 퀴즈 시작 |
| POST | `/kana/quiz/answer` | 가나 퀴즈 답변 |
| POST | `/kana/stage-complete` | 가나 스테이지 완료 |

### Chat (`/api/v1/chat`)
| Method | Path | 설명 |
|--------|------|------|
| GET | `/chat/scenarios` | 시나리오 목록 |
| GET | `/chat/history` | 대화 히스토리 (커서 페이지네이션) |
| GET | `/chat/characters` | AI 캐릭터 목록 |
| GET | `/chat/characters?id=` | 캐릭터 상세 |
| GET | `/chat/characters/stats` | 캐릭터별 대화 수 |
| GET | `/chat/characters/favorites` | 즐겨찾기 캐릭터 |
| POST | `/chat/characters/favorites` | 즐겨찾기 토글 |
| GET | `/chat/{id}` | 대화 상세 |
| DELETE | `/chat/{id}` | 대화 삭제 |
| POST | `/chat/start` | 대화 시작 |
| POST | `/chat/message` | 메시지 전송 |
| POST | `/chat/end` | 대화 종료 + 피드백 |
| POST | `/chat/tts` | TTS 음성 변환 |
| POST | `/chat/voice/transcribe` | 음성 인식 |
| POST | `/chat/live-token` | 실시간 대화 토큰 |
| POST | `/chat/live-feedback` | 음성 대화 피드백 |

### Missions (`/api/v1/missions`)
| Method | Path | 설명 |
|--------|------|------|
| GET | `/missions/today` | 오늘의 미션 (3개) |
| POST | `/missions/claim` | 미션 보상 수령 |

### Subscription (`/api/v1/subscription`)
| Method | Path | 설명 |
|--------|------|------|
| GET | `/subscription/status` | 구독 상태 + AI 사용량 |
| POST | `/subscription/checkout` | 결제 세션 생성 |
| POST | `/subscription/activate` | 구독 활성화 |
| POST | `/subscription/cancel` | 구독 취소 |
| POST | `/subscription/resume` | 구독 재개 |

### Payments (`/api/v1/payments`)
| Method | Path | 설명 |
|--------|------|------|
| GET | `/payments/` | 결제 내역 |

### Notifications (`/api/v1/notifications`)
| Method | Path | 설명 |
|--------|------|------|
| GET | `/notifications/` | 알림 목록 + 읽지 않은 수 |
| PATCH | `/notifications/` | 알림 읽음 처리 |

### Push (`/api/v1/push`)
| Method | Path | 설명 |
|--------|------|------|
| POST | `/push/subscribe` | 푸시 구독 등록 |

### TTS (`/api/v1/vocab`)
| Method | Path | 설명 |
|--------|------|------|
| POST | `/vocab/tts` | 단어 TTS 생성 + GCS 캐시 |

### 기타
| Method | Path | 설명 |
|--------|------|------|
| GET | `/health` | 헬스체크 |
| POST | `/cron/subscription-renewal` | 구독 만료 처리 (크론) |
| POST | `/webhook/portone` | 포트원 결제 웹훅 |

---

## 2. 화면별 분석

### 2.1 스플래시 / 앱 소개 슬라이드

- **필요 데이터**: 없음 (정적 UI)
- **현재 API**: 없음
- **갭**: 없음 -- 프론트엔드만

### 2.2 로그인 / 회원가입

- **필요 데이터**: Supabase Auth (카카오/구글 소셜 로그인)
- **현재 API**: `POST /auth/ensure-user` (로그인 후 DB 유저 동기화)
- **갭**: 없음 -- 현행 유지

### 2.3 온보딩

- **필요 데이터**: 닉네임, JLPT 레벨, 가나 학습 여부, 학습 목표
- **현재 API**: `POST /auth/onboarding`
- **갭**:
  - **[기존 API 수정]** `POST /auth/onboarding` -- `show_kana` 필드 추가 필요. 현재는 `nickname`, `jlpt_level`, `daily_goal`, `goal`만 받음. v2에서는 N5 선택 시 가나 학습 여부를 온보딩에서 선택하므로 `show_kana: bool` 파라미터 추가 필요.

### 2.4 홈 화면 (`/home`)

#### 필요 데이터:
1. **헤더**: 닉네임, 알림 읽지 않은 수
2. **스트릭 섹션**: 연속 학습 일수 (컴팩트)
3. **달력 바텀시트**: 월별 학습 기록
4. **오늘의 학습 카드**: 탭별(단어/문법/문장) 추천 학습 콘텐츠, 복습할 단어 수
5. **학습 정보**: 오늘 푼 문제 수, 정답률
6. **바로가기**: 단어장/오답노트/도전과제/가나차트 (링크만, 데이터 불필요)

#### 현재 API:
- `GET /stats/dashboard` -- 오늘 통계, 스트릭, 주간, 레벨 진도, 가나 진도
- `GET /user/profile` -- 닉네임 등 프로필 정보
- `GET /notifications/` -- `unreadCount` 포함
- `GET /quiz/recommendations` -- 복습 예정/신규/오답 카운트
- `GET /stats/history?year=&month=` -- 달력용 월별 기록

#### 갭:
- **[기존 API 수정]** `GET /quiz/recommendations`:
  - 현재: `reviewDueCount`, `newWordsCount`, `wrongCount`만 반환 (총합 숫자만)
  - 필요: **카테고리별(단어/문법/문장)** 추천 데이터 필요. 탭이 단어|문법|문장으로 나뉘므로 각 카테고리별 복습 예정 수, 신규 수를 분리해서 반환해야 함.
  - 수정안: 응답에 `byCategory: { vocabulary: { reviewDue: n, new: n }, grammar: { reviewDue: n, new: n }, sentence: { reviewDue: n, new: n } }` 추가

- **[프론트엔드 변경]** 홈에서 missions 호출을 제거하고, 대신 recommendations를 메인 카드로 활용. 홈 repository에서 `fetchTodayMissions()` 대신 `fetchRecommendations()` 호출로 전환.

### 2.5 학습 페이지 (`/study`)

#### 필요 데이터:
1. **탭 구성**: 단어 | 문법 | 문장배열 | [가나] (동적)
2. **현재 JLPT 레벨**: 유저 설정값
3. **스테이지 리스트**: 카테고리(단어/문법/문장) + JLPT 레벨별 스테이지 목록
4. **스테이지별 진도**: 전체 진도(%), 모드별 완료 여부
5. **모드 선택 바텀시트**: 사용 가능 모드, 하루 목표 설정

#### 현재 API:
- `GET /quiz/stats?level=N5&type=VOCABULARY` -- 레벨+타입별 총 수/학습 수/진도(%)
- `GET /user/profile` -- `jlptLevel`, `showKana`
- `GET /kana/stages` -- 가나 스테이지만 존재

#### 갭:
- **[신규 API 필요]** `GET /api/v1/study/stages?category=vocabulary&level=N5`
  - **핵심 누락**: 현재 단어/문법/문장에 대한 "스테이지" 개념이 DB/API 모두에 존재하지 않음. 가나만 `KanaLearningStage` 모델이 있음.
  - Vocabulary 모델에는 `part_of_speech` 필드가 있으므로, 이를 기준으로 스테이지를 동적 생성하거나, 별도 `VocabStage` / `GrammarStage` / `SentenceStage` 테이블을 만들어야 함.
  - 응답 예시:
    ```json
    {
      "stages": [
        {
          "id": "stage-uuid",
          "title": "N5 동사 기초",
          "description": "기본 동사 20개",
          "category": "vocabulary",
          "jlptLevel": "N5",
          "stageNumber": 1,
          "totalItems": 20,
          "isUnlocked": true,
          "isCompleted": false,
          "overallProgress": 80,
          "modeProgress": {
            "multiple_choice": { "completed": true, "accuracy": 90 },
            "matching": { "completed": true, "accuracy": 85 },
            "cloze": { "completed": false, "accuracy": null }
          }
        }
      ]
    }
    ```

- **[신규 DB 모델 필요]** 스테이지 관련 테이블:
  - `study_stages` -- 단어/문법/문장 스테이지 정의 (category, jlpt_level, stage_number, title, description, item_ids/filter)
  - `user_stage_progress` -- 유저별 스테이지 진도 (stage_id, user_id, is_unlocked, mode별 완료 여부, accuracy)

- **[기존 API 수정]** `POST /quiz/start`:
  - 현재: `quiz_type` + `jlpt_level` + `count` + `mode`로 랜덤 문제 출제
  - 필요: `stage_id` 파라미터 추가, 해당 스테이지에 속한 아이템만으로 문제 출제
  - 수정안: `body`에 `stageId: UUID | null` 추가. stageId가 있으면 해당 스테이지 아이템만, 없으면 현행 로직 유지.

- **[기존 API 수정]** `POST /quiz/complete`:
  - 필요: `stageId`가 포함된 퀴즈 완료 시, `user_stage_progress`도 업데이트하고, 모든 모드 완료 시 다음 스테이지 해금

- **[신규 API 필요]** `PATCH /api/v1/study/daily-goal`
  - v2에서 하루 목표는 학습 진입 시 바텀시트에서 카테고리별로 설정
  - 현재 `daily_goal`은 유저 모델에 단일 값으로만 존재
  - 카테고리별 목표 저장을 위해 유저 모델에 `daily_goals: JSON` 필드 추가하거나, 별도 설정 API 필요
  - 요청: `{ "category": "vocabulary", "count": 10 }`
  - 대안: `PATCH /user/profile`의 기존 로직에 `daily_goals` JSON 필드를 추가해 처리 가능

### 2.6 퀴즈 화면 (풀스크린)

#### 필요 데이터:
1. 문제 목록 (4지선다/매칭/빈칸/어순/가나)
2. 답변 검증
3. 퀴즈 완료 결과

#### 현재 API:
- `POST /quiz/start` -- 문제 생성 (mode: normal/cloze/arrange/review)
- `POST /quiz/answer` -- 답변 처리
- `POST /quiz/complete` -- 완료 처리
- `POST /quiz/resume` -- 이어하기
- `POST /kana/quiz/start`, `/kana/quiz/answer` -- 가나 퀴즈

#### 갭:
- **[기존 API 수정]** `POST /quiz/start` -- 매칭 모드 추가 필요:
  - 현재 mode: `normal`, `cloze`, `arrange`, `review`
  - 필요: `matching` 모드 추가 (좌측 일본어 ↔ 우측 한국어 짝짓기)
  - 매칭 모드는 여러 아이템을 한 화면에 보여주는 특수한 형태이므로, 응답 구조가 달라야 함
  - 매칭 응답 예시:
    ```json
    {
      "sessionId": "...",
      "questions": [{
        "questionId": "matching-round-1",
        "pairs": [
          { "id": "v1", "japanese": "食べる", "korean": "먹다" },
          { "id": "v2", "japanese": "飲む", "korean": "마시다" },
          ...
        ]
      }],
      "totalQuestions": 3
    }
    ```

- **[프론트엔드 변경]** 퀴즈 중 탭바 숨김 -- API 불필요
- **[프론트엔드 변경]** 닫기 시 확인 다이얼로그 -- API 불필요

### 2.7 퀴즈 결과 화면

- **필요 데이터**: 점수, 정답률, XP, 오답 목록
- **현재 API**: `POST /quiz/complete` + `GET /quiz/wrong-answers?sessionId=`
- **갭**: 없음 -- 현행 유지. 단어장 저장은 기존 `POST /wordbook/` 활용.

### 2.8 학습통계 페이지 (`/stats`)

#### 필요 데이터:

**기간별 탭:**
1. 오늘의 학습 요약 (학습 시간, 문제 수)
2. 연간 학습 히트맵 (GitHub 스타일, 365일)
3. 학습 시간 차트 (주/월/년/전체, 라인차트)
4. 학습량 차트 (카테고리별 색상 바차트)

**학습별 탭:**
1. 서브탭별(단어/문법/문장배열/실전회화) 트로피 수, 총 학습 문제, 학습 시간
2. 7일 바차트 (새로 배운/이미 아는/복습/정답률)

**JLPT 진도 탭:**
1. 레벨별 달성률 (N5~N1)
2. 카테고리별 breakdown (N5 단어: 85%, 문법: 70%)
3. 전체 유저 대비 상위 % (v2 이후)

#### 현재 API:
- `GET /stats/dashboard` -- 오늘 통계, 주간 통계, 현재 JLPT 레벨의 단어/문법 진도
- `GET /stats/history?year=&month=` -- 월별 DailyProgress 기록
- `GET /quiz/stats?level=&type=` -- 레벨+타입별 진도

#### 갭:

- **[신규 API 필요]** `GET /api/v1/stats/heatmap?year=2026`
  - 연간 학습 히트맵 전용 엔드포인트
  - 현재 `GET /stats/history`는 월 단위이므로 연간 히트맵을 위해 12번 호출 필요 (비효율적)
  - 응답: `{ "year": 2026, "data": [{ "date": "2026-01-01", "level": 3, "totalMinutes": 15 }, ...] }`
  - `level`은 0~4 (GitHub 스타일 강도)

- **[신규 API 필요]** `GET /api/v1/stats/time-chart?period=week|month|year|all`
  - 학습 시간 차트 데이터
  - 현재 `DailyProgress`에 `study_time_seconds` 필드가 있지만, 실제로 학습 시간 추적이 제대로 안 되고 있음 (기본값 0)
  - **[중요]** 학습 시간 추적 로직 추가 필요: 퀴즈 세션의 `time_spent_seconds` 합산, 대화 시간 합산 등
  - 응답: `{ "period": "week", "data": [{ "label": "3/7", "minutes": 15 }], "averageMinutes": 12 }`

- **[신규 API 필요]** `GET /api/v1/stats/volume-chart?period=week|month|year|all`
  - 학습량 차트 (카테고리별)
  - 현재 `DailyProgress`에 카테고리별 분리 데이터가 없음 (`words_studied`만 있고, grammar/sentence 별도 구분 없음)
  - **[DB 수정 필요]** `DailyProgress` 테이블에 `grammar_studied`, `sentences_studied` 컬럼 추가
  - 응답: `{ "period": "week", "data": [{ "label": "3/7", "vocabulary": 10, "grammar": 5, "sentence": 3 }] }`

- **[신규 API 필요]** `GET /api/v1/stats/by-category?category=vocabulary`
  - 학습별 탭용 카테고리별 상세 통계
  - 트로피 수 (업적 중 해당 카테고리 관련), 총 학습 문제 수, 총 학습 시간
  - 7일간 데이터: 새로 배운 수, 이미 아는 수, 복습 수, 정답률
  - 응답:
    ```json
    {
      "category": "vocabulary",
      "trophies": 5,
      "totalQuestions": 896,
      "totalStudyTimeFormatted": "12:30",
      "todayStudyTimeFormatted": "0:15",
      "weeklyBreakdown": [
        {
          "date": "2026-03-07",
          "newCount": 5,
          "knownCount": 10,
          "reviewCount": 8,
          "reviewAccuracy": 85.5
        }
      ]
    }
    ```
  - **[DB 변경 필요]** `QuizSession` 또는 `QuizAnswer`에서 카테고리별 집계 로직 필요. 현재 `QuizSession.quiz_type`이 VOCABULARY/GRAMMAR 구분이 있으므로 집계는 가능하나, 문장배열과 실전회화의 별도 집계 로직 추가 필요.

- **[신규 API 필요]** `GET /api/v1/stats/jlpt-progress`
  - 모든 JLPT 레벨의 진도를 한 번에 반환
  - 현재 `GET /quiz/stats?level=N5&type=VOCABULARY`는 한 레벨+한 타입만 조회 가능
  - 모든 레벨(N5~N1) x 모든 카테고리(단어/문법)를 한 번에 조회하려면 10번 API 호출 필요
  - 응답:
    ```json
    {
      "levels": [
        {
          "level": "N5",
          "overallProgress": 82,
          "vocabulary": { "total": 800, "studied": 680, "progress": 85 },
          "grammar": { "total": 100, "studied": 70, "progress": 70 }
        },
        { "level": "N4", "overallProgress": 30, "vocabulary": {...}, "grammar": {...} },
        { "level": "N3", "overallProgress": 0, "vocabulary": {...}, "grammar": {...} },
        { "level": "N2", "locked": true },
        { "level": "N1", "locked": true }
      ]
    }
    ```
  - 해금 조건: 이전 레벨의 overallProgress가 일정 수준(예: 70%) 이상이면 다음 레벨 해금

- **[DB 수정 필요]** `DailyProgress` 테이블 확장:
  - `grammar_studied: int` -- 문법 학습 수
  - `sentences_studied: int` -- 문장 학습 수
  - `study_time_seconds` -- 현재 존재하지만 값이 업데이트되지 않음. `POST /quiz/complete`와 `POST /chat/end`에서 실제 학습 시간을 누적해야 함.

### 2.9 실전회화 페이지 (`/chat`)

#### 필요 데이터:
1. 추천 시나리오 (유저 레벨 기반)
2. 카테고리별 시나리오 (일상/여행/비즈니스)
3. 최근 학습한 대화
4. 통화 설정 (침묵 시간, 자막, 자동 분석)

#### 현재 API:
- `GET /chat/scenarios` -- 시나리오 목록 (category, difficulty 포함)
- `GET /chat/history` -- 대화 히스토리
- `PATCH /user/profile` -- call_settings 수정
- `GET /user/profile` -- call_settings 조회

#### 갭:
- **[기존 API 수정]** `GET /chat/scenarios`:
  - 현재: 전체 시나리오를 `order` 순으로 반환
  - 필요: 유저의 JLPT 레벨에 맞는 추천 시나리오를 상단에, 카테고리별 그룹핑 필요
  - 수정안: 응답에 `recommended: [...]` 섹션 추가, 또는 `?recommended=true&level=N5` 쿼리 파라미터 지원
  - 또는 프론트에서 difficulty와 유저 레벨을 매핑하여 필터링 (추가 API 없이 가능)

- **[프론트엔드 변경]** 통화 설정을 마이페이지에서 실전회화 페이지 내로 이동 -- API는 기존 `PATCH /user/profile`의 `call_settings` 활용 가능

### 2.10 마이페이지 (`/my`)

#### 필요 데이터:
1. **프로필 히어로**: 아바타, 닉네임, JLPT 레벨, 레벨/XP, 학습일/단어/XP/연속 통계
2. **구독**: 프리미엄 상태, 결제 내역
3. **학습 설정**: JLPT 레벨, 가나 학습 표시
4. **앱 설정**: 테마, 후리가나 표시, 학습 리마인더, 스트릭 방어 알림
5. **정보**: 이용약관, 개인정보처리방침, 문의하기
6. **계정**: 로그아웃, 회원 탈퇴

#### 현재 API:
- `GET /user/profile` -- 프로필 + 통계 + 업적
- `PATCH /user/profile` -- 프로필 수정
- `GET /subscription/status` -- 구독 상태
- `GET /payments/` -- 결제 내역
- `DELETE /user/account` -- 계정 삭제

#### 갭:
- **[기존 API 수정]** `PATCH /user/profile`:
  - 필요: `show_kana` 수정 지원 확인 -- 현재 `UserProfileUpdate` 스키마에 `show_kana` 필드가 있는지 확인 필요. User 모델에는 존재함.
  - 필요: 앱 설정 필드 추가 -- 현재 User 모델에 다음 필드 없음:
    - `theme_mode: str` (라이트/다크)
    - `show_furigana: bool` (후리가나 표시)
    - `reminder_enabled: bool` (학습 리마인더)
    - `reminder_time: str` (리마인더 시간, 예: "20:00")
    - `streak_alert_enabled: bool` (스트릭 방어 알림)

- **[DB 수정 필요]** User 모델에 앱 설정 필드 추가:
  - 방법 A: 개별 컬럼 추가 -- 명시적이지만 마이그레이션 필요
  - 방법 B (권장): `app_settings: JSON` 컬럼 추가 -- 유연하고 확장 쉬움. `call_settings`와 동일한 패턴.
    ```json
    {
      "themeMode": "light",
      "showFurigana": true,
      "reminderEnabled": true,
      "reminderTime": "20:00",
      "streakAlertEnabled": true
    }
    ```

- **[프론트엔드 변경]** 업적 섹션 제거 -- 홈 바로가기 "도전과제"로 이동. API 변경 불필요 (기존 `GET /user/profile` 의 achievements 데이터 활용).
- **[프론트엔드 변경]** 하루 목표 설정 제거 -- 학습 페이지로 이동. API 변경 불필요.

### 2.11 도전과제 화면 (홈 바로가기)

- **필요 데이터**: 전체 업적 목록 + 유저 달성 여부
- **현재 API**: `GET /user/profile` -- `achievements` 배열 (달성한 것만)
- **갭**:
  - **[신규 API 필요]** `GET /api/v1/achievements`
    - 전체 업적 정의 목록 + 유저 달성 상태
    - 현재는 유저가 달성한 업적만 `UserAchievement` 테이블에서 가져옴. 전체 업적 카탈로그가 코드 내 상수로만 존재.
    - 응답:
      ```json
      {
        "achievements": [
          {
            "type": "first_quiz",
            "title": "첫 퀴즈 완료",
            "description": "첫 번째 퀴즈를 완료했어요",
            "emoji": "🎯",
            "achieved": true,
            "achievedAt": "2026-03-01T..."
          },
          {
            "type": "streak_7",
            "title": "7일 연속 학습",
            "description": "7일 연속으로 학습했어요",
            "emoji": "🔥",
            "achieved": false,
            "achievedAt": null
          }
        ]
      }
      ```

### 2.12 가나 차트 화면 (홈 바로가기 -- 50음도)

- **필요 데이터**: 전체 가나 문자 + 유저 학습 진도
- **현재 API**: `GET /kana/characters` + `GET /kana/progress`
- **갭**: 없음 -- 현행 API로 충분. 프론트엔드에서 차트 UI만 구현.

---

## 3. 작업 분류

### 3.1 프론트엔드만 변경 (API 불필요)

| 항목 | 설명 |
|------|------|
| 스플래시 / 앱 소개 슬라이드 | 정적 UI |
| 하단 탭 이름 변경 | "회화" → "실전회화" |
| 퀴즈 중 탭바 숨김 | 풀스크린 모드 (UI 레이어) |
| 퀴즈 종료 확인 다이얼로그 | UI only |
| 홈 바로가기 4개 | 단순 네비게이션 링크 |
| 스트릭 → 달력 바텀시트 UX | 기존 `/stats/history` 활용 |
| 통화 설정 위치 이동 | 마이페이지 → 실전회화 (기존 API 재활용) |
| 업적 위치 이동 | 마이페이지 → 홈 바로가기 (기존 API 재활용) |
| 학습 페이지 탭 구조 변경 | 추천/자율 → 단어\|문법\|문장\|가나 |
| 가나 탭 동적 표시/숨김 | `showKana` 플래그 기반 프론트 로직 |
| 쓰기(타이핑) 모드 비활성 | UI에서 선택지 제거 |
| 가나 차트(50음도) 화면 | 기존 API로 구현 가능 |
| 시나리오 카테고리별 필터링 | 기존 응답의 `category` 필드로 프론트 필터 |

### 3.2 기존 API 수정 필요

| API | 수정 내용 | 영향 범위 |
|-----|----------|----------|
| `POST /auth/onboarding` | `show_kana: bool` 파라미터 추가 | OnboardingRequest 스키마 수정 |
| `GET /quiz/recommendations` | 카테고리별(vocab/grammar/sentence) 분리 응답 추가 | 쿼리 로직 확장 |
| `POST /quiz/start` | `stageId: UUID` 파라미터 추가, 매칭 모드(`matching`) 추가 | QuizStartRequest 스키마 + 문제 생성 로직 |
| `POST /quiz/complete` | `stageId` 포함 시 스테이지 진도 업데이트 | 스테이지 완료 로직 추가 |
| `PATCH /user/profile` | `app_settings: JSON` 필드 지원 (테마, 후리가나, 리마인더 등) | UserProfileUpdate 스키마 수정 |
| `POST /quiz/complete` & `POST /chat/end` | `DailyProgress.study_time_seconds` 실제 업데이트 | 시간 추적 로직 추가 |
| `POST /quiz/complete` | `DailyProgress`에 grammar_studied, sentences_studied 누적 | DailyProgress 업데이트 로직 |

### 3.3 신규 API 필요

| API | 설명 | 요청/응답 |
|-----|------|----------|
| `GET /api/v1/study/stages` | 스테이지 목록 (카테고리 + 레벨별) | `?category=vocabulary&level=N5` → 스테이지 리스트 + 모드별 진도 |
| `GET /api/v1/stats/heatmap` | 연간 학습 히트맵 | `?year=2026` → 365일 학습 강도 데이터 |
| `GET /api/v1/stats/time-chart` | 학습 시간 차트 | `?period=week` → 기간별 학습 시간 |
| `GET /api/v1/stats/volume-chart` | 학습량 차트 (카테고리별) | `?period=week` → 단어/문법/문장별 학습량 |
| `GET /api/v1/stats/by-category` | 카테고리별 상세 통계 | `?category=vocabulary` → 트로피/총문제/7일 breakdown |
| `GET /api/v1/stats/jlpt-progress` | 전체 JLPT 레벨 진도 | 모든 레벨 x 카테고리 진도 한 번에 |
| `GET /api/v1/achievements` | 전체 업적 카탈로그 + 달성 상태 | 업적 정의 + 유저 달성 여부 |
| `PATCH /api/v1/study/daily-goal` | 카테고리별 하루 목표 설정 | `{ "category": "vocabulary", "count": 10 }` |

### 3.4 신규 DB 모델/마이그레이션 필요

| 대상 | 변경 내용 |
|------|----------|
| **`study_stages` 테이블 (신규)** | `id`, `category` (vocabulary/grammar/sentence), `jlpt_level`, `stage_number`, `title`, `description`, `filter_criteria` (JSON -- part_of_speech 등), `item_count`, `order` |
| **`user_study_stage_progress` 테이블 (신규)** | `id`, `user_id`, `stage_id`, `is_unlocked`, `mode_progress` (JSON -- 모드별 완료/정확도), `overall_progress`, `completed_at` |
| **`daily_progress` 컬럼 추가** | `grammar_studied: int`, `sentences_studied: int` |
| **`users` 컬럼 추가** | `app_settings: JSON` (테마, 후리가나, 리마인더 등), `daily_goals: JSON` (카테고리별 하루 목표) |

---

## 4. 우선순위 및 의존성

### P0 — 블로킹 (학습 페이지 핵심 구조)

| 순서 | 작업 | 블로킹 대상 | 예상 공수 |
|------|------|-----------|----------|
| 1 | `study_stages` + `user_study_stage_progress` DB 모델 설계 및 마이그레이션 | 모든 학습 페이지 작업 | 1일 |
| 2 | 스테이지 시드 데이터 생성 (N5 단어/문법/문장) | 스테이지 API | 1일 |
| 3 | `GET /study/stages` API 구현 | 학습 페이지 스테이지 리스트 UI | 1일 |
| 4 | `POST /quiz/start`에 `stageId` + `matching` 모드 추가 | 스테이지 기반 퀴즈 시작 | 1일 |
| 5 | `POST /quiz/complete`에 스테이지 진도 업데이트 추가 | 스테이지 진도 반영 | 0.5일 |

### P1 — 중요 (홈 화면 개선)

| 순서 | 작업 | 블로킹 대상 | 예상 공수 |
|------|------|-----------|----------|
| 6 | `GET /quiz/recommendations` 카테고리별 분리 | 홈 오늘의 학습 카드 탭 | 0.5일 |
| 7 | `POST /auth/onboarding`에 `show_kana` 추가 | 온보딩 → 가나 탭 동적 표시 | 0.5일 |

### P2 — 통계 페이지

| 순서 | 작업 | 블로킹 대상 | 예상 공수 |
|------|------|-----------|----------|
| 8 | `DailyProgress` 테이블 확장 (grammar_studied, sentences_studied) + 학습 시간 추적 로직 | 모든 통계 차트 | 1일 |
| 9 | `GET /stats/heatmap` 구현 | 기간별 탭 히트맵 | 0.5일 |
| 10 | `GET /stats/jlpt-progress` 구현 | JLPT 진도 탭 | 0.5일 |
| 11 | `GET /stats/time-chart` + `GET /stats/volume-chart` 구현 | 기간별 탭 차트 | 1일 |
| 12 | `GET /stats/by-category` 구현 | 학습별 탭 | 1일 |

### P3 — 마이페이지 & 부가 기능

| 순서 | 작업 | 블로킹 대상 | 예상 공수 |
|------|------|-----------|----------|
| 13 | User 모델에 `app_settings` JSON 컬럼 추가 + `PATCH /user/profile` 수정 | 마이페이지 앱 설정 | 0.5일 |
| 14 | `GET /achievements` 전체 업적 카탈로그 API | 도전과제 화면 | 0.5일 |
| 15 | 카테고리별 daily_goal 지원 | 학습 진입 시 목표 설정 바텀시트 | 0.5일 |

### 의존성 다이어그램

```
[DB: study_stages 모델] ──→ [시드 데이터] ──→ [GET /study/stages]
                                              ↓
                                    [POST /quiz/start 수정]
                                              ↓
                                    [POST /quiz/complete 수정]
                                              ↓
                                    [프론트: 학습 페이지 스테이지 UI]

[DB: DailyProgress 확장] ──→ [학습 시간 추적 로직]
                              ↓
                    [GET /stats/heatmap]
                    [GET /stats/time-chart]
                    [GET /stats/volume-chart]
                    [GET /stats/by-category]
                    [GET /stats/jlpt-progress]
                              ↓
                    [프론트: 학습통계 3탭 구현]

[DB: users.app_settings] ──→ [PATCH /user/profile 수정]
                              ↓
                    [프론트: 마이페이지 앱 설정 UI]
```

---

## 5. 요약

| 분류 | 건수 |
|------|------|
| 프론트엔드만 변경 | 13건 |
| 기존 API 수정 | 7건 |
| 신규 API 개발 | 8건 |
| DB 모델/마이그레이션 | 4건 |
| **총 백엔드 작업** | **~10일** (1인 기준 예상) |

가장 큰 갭은 **학습 페이지의 스테이지 시스템**으로, DB 모델부터 API, 시드 데이터까지 전면 신규 개발이 필요합니다. 기존 가나 스테이지(`KanaLearningStage`) 패턴을 참고하여 단어/문법/문장용 범용 스테이지 시스템을 설계하는 것이 효율적입니다.
